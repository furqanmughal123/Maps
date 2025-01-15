import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../services/routing_service.dart' as routing;

class NavigationPanel extends StatefulWidget {
  final LatLng startLocation;
  final LatLng endLocation;
  final Function(routing.Route) onRouteSelected;

  const NavigationPanel({
    super.key,
    required this.startLocation,
    required this.endLocation,
    required this.onRouteSelected,
  });

  @override
  State<NavigationPanel> createState() => _NavigationPanelState();
}

class _NavigationPanelState extends State<NavigationPanel> {
  routing.TravelMode selectedMode = routing.TravelMode.driving;
  routing.Route? currentRoute;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _getRoute();
  }

  Future<void> _getRoute() async {
    if (!mounted) return;
    
    setState(() {
      isLoading = true;
    });

    try {
      final route = await routing.RoutingService.getRoute(
        widget.startLocation,
        widget.endLocation,
        selectedMode,
      );
      
      if (!mounted) return;
      
      setState(() {
        currentRoute = route;
        widget.onRouteSelected(route);
      });
    } catch (e) {
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error getting route: $e')),
      );
    } finally {
      if (!mounted) return;
      
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildModeButton(routing.TravelMode.driving, Icons.directions_car),
              _buildModeButton(routing.TravelMode.walking, Icons.directions_walk),
              _buildModeButton(routing.TravelMode.cycling, Icons.directions_bike),
              _buildModeButton(routing.TravelMode.transit, Icons.directions_bus),
            ],
          ),
          if (isLoading)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: CircularProgressIndicator(),
            )
          else if (currentRoute != null)
            _buildRouteDetails(),
        ],
      ),
    );
  }

  Widget _buildModeButton(routing.TravelMode mode, IconData icon) {
    return IconButton(
      icon: Icon(icon),
      color: selectedMode == mode ? Colors.blue : Colors.grey,
      onPressed: () {
        setState(() {
          selectedMode = mode;
          _getRoute();
        });
      },
    );
  }

  Widget _buildRouteDetails() {
    String modeText = '';
    switch (selectedMode) {
      case routing.TravelMode.driving:
        modeText = '🚗 Driving';
        break;
      case routing.TravelMode.walking:
        modeText = '🚶 Walking';
        break;
      case routing.TravelMode.cycling:
        modeText = '🚲 Cycling';
        break;
      case routing.TravelMode.transit:
        modeText = '🚌 Transit';
        break;
    }

    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  modeText,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Distance: ${_formatDistance(currentRoute!.totalDistance)}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  'Estimated Time: ${_formatDuration(currentRoute!.totalDuration)}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: ListView.builder(
              itemCount: currentRoute!.steps.length,
              itemBuilder: (context, index) {
                final step = currentRoute!.steps[index];
                return ListTile(
                  leading: CircleAvatar(
                    child: Text('${index + 1}'),
                  ),
                  title: Text(step.instruction),
                  subtitle: Text(
                    '${_formatDistance(step.distance)} • '
                    '${_formatDuration(step.duration)}',
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _formatDistance(double meters) {
    if (meters >= 1000) {
      return '${(meters / 1000).toStringAsFixed(1)} km';
    }
    return '${meters.toStringAsFixed(0)} m';
  }

  String _formatDuration(double seconds) {
    if (seconds >= 3600) {
      final hours = (seconds / 3600).floor();
      final minutes = ((seconds % 3600) / 60).round();
      return '$hours h $minutes min';
    } else if (seconds >= 60) {
      return '${(seconds / 60).round()} min';
    }
    return '${seconds.round()} sec';
  }
} 