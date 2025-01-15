import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'services/nominatim_service.dart';
import 'services/language_service.dart';
import 'widgets/navigation_panel.dart';
import 'services/routing_service.dart' as routing;
import 'dart:developer' as developer;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter OSM Map',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const MapScreen(),
    );
  }
}

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  static const LatLng pakistanCenter = LatLng(30.3753, 69.3451);
  static const Map<String, LatLng> pakistanCities = {
    'Islamabad': LatLng(33.6844, 73.0479),
    'Karachi': LatLng(24.8607, 67.0011),
    'Lahore': LatLng(31.5204, 74.3587),
    'Peshawar': LatLng(34.0151, 71.5249),
    'Quetta': LatLng(30.1798, 66.9750),
  };
  
  LatLng? currentLocation;
  final MapController mapController = MapController();
  final TextEditingController searchController = TextEditingController();
  List<SearchLocation> searchResults = [];
  bool isSearching = false;
  LanguageOption selectedLanguage = LanguageService.supportedLanguages[0];
  LatLng? destinationLocation;
  bool isNavigating = false;
  routing.Route? activeRoute;
  LatLng? firstMarker;
  LatLng? secondMarker;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      mapController.move(pakistanCities['Karachi']!, 11.0);
    });
  }

  Future<void> _getCurrentLocation() async {
    try {
      // Request location permission
      LocationPermission permission = await Geolocator.requestPermission();
      
      if (permission == LocationPermission.denied) {
        return;
      }

      // Get current position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        currentLocation = LatLng(position.latitude, position.longitude);
      });
    } catch (e) {
      developer.log("Error getting location: $e", name: 'MapScreen');
    }
  }

  void _searchLocation(String query) async {
    if (query.isEmpty) {
      setState(() {
        searchResults = [];
        isSearching = false;
      });
      return;
    }

    setState(() {
      isSearching = true;
    });

    try {
      final results = await NominatimService.searchLocation(query, selectedLanguage.code);
      setState(() {
        searchResults = results;
        isSearching = false;
      });
    } catch (e) {
      developer.log('Error searching location: $e', name: 'MapScreen');
      setState(() {
        isSearching = false;
      });
    }
  }

  void _goToLocation(SearchLocation location) {
    mapController.move(location.coordinates, 13.0);
    if (currentLocation != null) {
      _startNavigation(location.coordinates);
    }
    setState(() {
      searchResults = [];
      searchController.clear();
    });
  }

  void _changeLanguage(LanguageOption? newLanguage) {
    if (newLanguage != null) {
      setState(() {
        selectedLanguage = newLanguage;
      });
      if (searchController.text.isNotEmpty) {
        _searchLocation(searchController.text);
      }
    }
  }

  void _startNavigation(LatLng destination) {
    setState(() {
      destinationLocation = destination;
      isNavigating = true;
    });
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.6,
        child: NavigationPanel(
          startLocation: currentLocation!,
          endLocation: destination,
          onRouteSelected: (route) {
            setState(() {
              activeRoute = route;
            });
          },
        ),
      ),
    );
  }

  void _handleMapTap(TapPosition tapPosition, LatLng point) {
    setState(() {
      if (firstMarker == null) {
        firstMarker = point;
      } else if (secondMarker == null) {
        secondMarker = point;
        _startNavigationBetweenPoints();
      } else {
        // Reset markers and start over
        firstMarker = point;
        secondMarker = null;
        activeRoute = null;
      }
    });
  }

  void _startNavigationBetweenPoints() {
    if (firstMarker != null && secondMarker != null) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (context) => SizedBox(
          height: MediaQuery.of(context).size.height * 0.6,
          child: NavigationPanel(
            startLocation: firstMarker!,
            endLocation: secondMarker!,
            onRouteSelected: (route) {
              setState(() {
                activeRoute = route;
              });
            },
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('OpenStreetMap Demo'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          PopupMenuButton<LanguageOption>(
            icon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.language),
                const SizedBox(width: 4),
                Text(selectedLanguage.code.toUpperCase(),
                    style: const TextStyle(fontSize: 12)),
              ],
            ),
            onSelected: _changeLanguage,
            itemBuilder: (BuildContext context) {
              return LanguageService.supportedLanguages
                  .map((LanguageOption language) {
                return PopupMenuItem<LanguageOption>(
                  value: language,
                  child: Row(
                    children: [
                      Text(language.name),
                      const SizedBox(width: 8),
                      if (language.code == selectedLanguage.code)
                        const Icon(Icons.check, size: 20),
                    ],
                  ),
                );
              }).toList();
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: mapController,
            options: MapOptions(
              initialCenter: pakistanCenter,
              initialZoom: 5.0,
              onTap: _handleMapTap,
              minZoom: 3.0,
              maxZoom: 18.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://{s}.tile.openstreetmap.de/{z}/{x}/{y}.png',
                subdomains: const ['a', 'b', 'c'],
                userAgentPackageName: 'com.example.app',
                fallbackUrl: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                additionalOptions: {
                  'accept-language': selectedLanguage.code,
                },
              ),
              MarkerLayer(
                markers: [
                  if (currentLocation != null)
                    Marker(
                      point: currentLocation!,
                      width: 80,
                      height: 80,
                      child: const Icon(
                        Icons.my_location,
                        color: Colors.blue,
                        size: 40,
                      ),
                    ),
                  if (firstMarker != null)
                    Marker(
                      point: firstMarker!,
                      width: 80,
                      height: 80,
                      child: const Icon(
                        Icons.place,
                        color: Colors.green,
                        size: 40,
                      ),
                    ),
                  if (secondMarker != null)
                    Marker(
                      point: secondMarker!,
                      width: 80,
                      height: 80,
                      child: const Icon(
                        Icons.place,
                        color: Colors.red,
                        size: 40,
                      ),
                    ),
                ],
              ),
              if (activeRoute != null)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: activeRoute!.polylinePoints,
                      strokeWidth: 4.0,
                      color: Colors.blue.withOpacity(0.8),
                      borderColor: Colors.blue.withOpacity(0.3),
                      borderStrokeWidth: 6.0,
                    ),
                  ],
                ),
            ],
          ),
          if (firstMarker == null)
            Positioned(
              top: 80,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Tap on the map to set start point',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            )
          else if (secondMarker == null)
            Positioned(
              top: 80,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Tap on the map to set destination',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          Positioned(
            top: 10,
            left: 10,
            right: 10,
            child: Column(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        spreadRadius: 1,
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: searchController,
                    decoration: InputDecoration(
                      hintText: selectedLanguage.searchHint,
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: isSearching
                          ? const Padding(
                              padding: EdgeInsets.all(8.0),
                              child: CircularProgressIndicator(),
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    onChanged: _searchLocation,
                  ),
                ),
                if (searchResults.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          spreadRadius: 1,
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: searchResults.length,
                      itemBuilder: (context, index) {
                        return ListTile(
                          title: Text(
                            searchResults[index].displayName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () => _goToLocation(searchResults[index]),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (firstMarker != null || secondMarker != null)
            FloatingActionButton(
              onPressed: () {
                setState(() {
                  firstMarker = null;
                  secondMarker = null;
                  activeRoute = null;
                });
              },
              child: const Icon(Icons.clear),
            ),
          const SizedBox(height: 16),
          FloatingActionButton(
            onPressed: () async {
              await _getCurrentLocation();
              if (currentLocation != null) {
                mapController.move(currentLocation!, 15.0);
              }
            },
            child: const Icon(Icons.my_location),
          ),
        ],
      ),
    );
  }
}
