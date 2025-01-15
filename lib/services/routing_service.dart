import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'dart:developer' as developer;

enum TravelMode {
  driving,
  walking,
  cycling,
  transit
}

class RouteStep {
  final String instruction;
  final double distance;
  final double duration;
  final LatLng startLocation;
  final LatLng endLocation;

  RouteStep({
    required this.instruction,
    required this.distance,
    required this.duration,
    required this.startLocation,
    required this.endLocation,
  });
}

class Route {
  final List<RouteStep> steps;
  final List<LatLng> polylinePoints;
  final double totalDistance;
  final double totalDuration;

  Route({
    required this.steps,
    required this.polylinePoints,
    required this.totalDistance,
    required this.totalDuration,
  });
}

class RoutingService {
  static const String _baseUrl = 'https://router.project-osrm.org/route/v1/';

  // Add average speeds for different modes (in meters per second)
  static const Map<TravelMode, double> _averageSpeeds = {
    TravelMode.driving: 13.89,  // 50 km/h
    TravelMode.walking: 1.4,    // 5 km/h
    TravelMode.cycling: 4.17,   // 15 km/h
    TravelMode.transit: 8.33,   // 30 km/h
  };

  static Future<Route> getRoute(
    LatLng start,
    LatLng end,
    TravelMode mode,
  ) async {
    final String profile = _getProfileForMode(mode);
    final url = '$_baseUrl$profile/'
        '${start.longitude},${start.latitude};'
        '${end.longitude},${end.latitude}'
        '?overview=full&steps=true&geometries=geojson';

    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['code'] != 'Ok') {
          throw Exception('Route not found');
        }
        return _parseRoute(data, mode);  // Pass the travel mode
      }
      throw Exception('Failed to get route: ${response.statusCode}');
    } catch (e) {
      developer.log('Routing error: $e', name: 'RoutingService');
      rethrow;
    }
  }

  static String _getProfileForMode(TravelMode mode) {
    switch (mode) {
      case TravelMode.driving:
        return 'driving';
      case TravelMode.walking:
        return 'foot';
      case TravelMode.cycling:
        return 'bike';
      case TravelMode.transit:
        return 'driving';
    }
  }

  static Route _parseRoute(Map<String, dynamic> data, TravelMode mode) {
    final route = data['routes'][0];
    final List<RouteStep> steps = [];
    final List<LatLng> polylinePoints = [];
    final double baseDistance = route['distance'].toDouble();

    // Calculate mode-specific duration based on average speed
    final double modeDuration = baseDistance / _averageSpeeds[mode]!;

    // Add traffic factor for driving and transit
    double adjustedDuration = modeDuration;
    if (mode == TravelMode.driving || mode == TravelMode.transit) {
      final hour = DateTime.now().hour;
      // Apply rush hour factor (7-9 AM and 4-7 PM)
      if ((hour >= 7 && hour <= 9) || (hour >= 16 && hour <= 19)) {
        adjustedDuration *= 1.5; // 50% slower during rush hour
      }
    }

    // Parse steps with mode-specific timing
    for (var leg in route['legs']) {
      for (var step in leg['steps']) {
        final maneuver = step['maneuver'];
        final location = maneuver['location'];
        final stepDistance = step['distance'].toDouble();
        
        // Calculate step duration based on mode
        final stepDuration = stepDistance / _averageSpeeds[mode]!;
        
        steps.add(RouteStep(
          instruction: _getStepInstruction(step, mode),
          distance: stepDistance,
          duration: stepDuration,
          startLocation: LatLng(location[1], location[0]),
          endLocation: LatLng(location[1], location[0]),
        ));
      }
    }

    // Parse geometry
    final coordinates = route['geometry']['coordinates'] as List;
    for (var coord in coordinates) {
      polylinePoints.add(LatLng(coord[1], coord[0]));
    }

    return Route(
      steps: steps,
      polylinePoints: polylinePoints,
      totalDistance: baseDistance,
      totalDuration: adjustedDuration,
    );
  }

  static String _getStepInstruction(Map<String, dynamic> step, TravelMode mode) {
    String baseInstruction = step['name'] ?? 'Continue';
    
    // Add mode-specific instructions
    switch (mode) {
      case TravelMode.driving:
        return baseInstruction;
      case TravelMode.walking:
        return 'Walk along $baseInstruction';
      case TravelMode.cycling:
        return 'Cycle along $baseInstruction';
      case TravelMode.transit:
        return 'Take transit along $baseInstruction';
    }
  }
} 