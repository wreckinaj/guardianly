import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class Directions extends StatefulWidget {
  final String fromLocation;
  final String toLocation;
  final String transportMode;

  const Directions({
    super.key,
    required this.fromLocation,
    required this.toLocation,
    required this.transportMode,
  });

  @override
  State<Directions> createState() => DirectionsState();
}

class DirectionsState extends State<Directions> {
  final MapController mapController = MapController();
  final String mapboxToken = dotenv.env['MAPBOX_ACCESS_TOKEN'] ?? '';
  
  List<LatLng> routePoints = [];
  List<DirectionStep> steps = [];
  bool isLoading = true;
  String? errorMessage;
  bool isPanelExpanded = true;
  
  // Duration and arrival time variables
  String totalDuration = '';
  String arrivalTime = '';
  double? totalDurationSeconds;
  String? trafficDelay;

  @override
  void initState() {
    super.initState();
    calculateRoute();
  }

  Future<void> calculateRoute() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
      trafficDelay = null;
    });

    try {
      final startCoords = await _getCoords(widget.fromLocation);
      final endCoords = await _getCoords(widget.toLocation);

      if (startCoords == null || endCoords == null) {
        setState(() {
          errorMessage = "Could not find one of the locations.";
          isLoading = false;
        });
        return;
      }

      final mode = widget.transportMode == 'drive' ? 'driving' : widget.transportMode;
      // URL with annotations=duration for traffic data
      final url = 'https://api.mapbox.com/directions/v5/mapbox/$mode/${startCoords.longitude},${startCoords.latitude};${endCoords.longitude},${endCoords.latitude}?geometries=geojson&steps=true&annotations=duration&access_token=$mapboxToken';
      
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final route = data['routes'][0];
        final List coords = route['geometry']['coordinates'];
        
        // Get standard duration
        final durationSeconds = route['duration']?.toDouble() ?? 0.0;
        
        // Get traffic-aware duration for driving
        double effectiveDuration = durationSeconds;
        if (widget.transportMode == 'drive' && route['duration_in_traffic'] != null) {
          effectiveDuration = route['duration_in_traffic'].toDouble();
          
          // Calculate delay
          final delaySeconds = effectiveDuration - durationSeconds;
          if (delaySeconds > 60) { // More than 1 minute delay
            trafficDelay = _formatDuration(delaySeconds);
          }
        }
        
        totalDurationSeconds = effectiveDuration;
        totalDuration = _formatDuration(effectiveDuration);
        arrivalTime = _calculateArrivalTime(effectiveDuration);
        
        // Parse the turn-by-turn steps (without duration)
        final List legs = route['legs'];
        List<DirectionStep> parsedSteps = [];
        int stepCount = 1;

        for (var leg in legs) {
          for (var step in leg['steps']) {
            parsedSteps.add(DirectionStep(
              instruction: step['maneuver']['instruction'],
              distance: "${(step['distance'] * 0.000621371).toStringAsFixed(1)} mi",
              stepNumber: stepCount++,
            ));
          }
        }

        setState(() {
          routePoints = coords.map((c) => LatLng(c[1].toDouble(), c[0].toDouble())).toList();
          steps = parsedSteps;
          isLoading = false;
        });

        if (routePoints.isNotEmpty) {
          _fitMapToRoute();
        }
      } else {
        throw Exception("Failed to load directions");
      }
    } catch (e) {
      setState(() {
        errorMessage = "Error: $e";
        isLoading = false;
      });
    }
  }

  String _formatDuration(double seconds) {
    if (seconds <= 0) return 'Unknown';
    
    final hours = (seconds / 3600).floor();
    final minutes = ((seconds % 3600) / 60).floor();
    
    if (hours > 0) {
      return '$hours hr ${minutes > 0 ? '$minutes min' : ''}';
    } else if (minutes > 0) {
      return '$minutes min';
    } else {
      return '${seconds.toInt()} sec';
    }
  }

  String _calculateArrivalTime(double durationSeconds) {
    final now = DateTime.now();
    final arrival = now.add(Duration(seconds: durationSeconds.toInt()));
    
    final hour = arrival.hour;
    final minute = arrival.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    
    final isTomorrow = arrival.day != now.day;
    
    if (isTomorrow) {
      return '$displayHour:$minute $period';
    } else {
      return '$displayHour:$minute $period';
    }
  }

  Future<LatLng?> _getCoords(String location) async {
    final url = 'https://api.mapbox.com/geocoding/v5/mapbox.places/${Uri.encodeComponent(location)}.json?access_token=$mapboxToken';
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['features'].isNotEmpty) {
        final center = data['features'][0]['center'];
        return LatLng(center[1].toDouble(), center[0].toDouble());
      }
    }
    return null;
  }

  void _fitMapToRoute() {
    if (routePoints.isEmpty) return;
    
    double minLat = routePoints[0].latitude;
    double maxLat = routePoints[0].latitude;
    double minLng = routePoints[0].longitude;
    double maxLng = routePoints[0].longitude;

    for (var point in routePoints) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLng) minLng = point.longitude;
      if (point.longitude > maxLng) maxLng = point.longitude;
    }

    mapController.fitCamera(
      CameraFit.bounds(
        bounds: LatLngBounds(LatLng(minLat, minLng), LatLng(maxLat, maxLng)),
        padding: const EdgeInsets.all(50.0),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Route Results", style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        // Change the back arrow to a close/exit button
        leading: IconButton(
          icon: const Icon(Icons.close, size: 28),
          onPressed: () {
            // Close the directions screen and return to the previous screen
            Navigator.of(context).pop();
          },
          tooltip: 'Close',
        ),
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: mapController,
            options: MapOptions(
              initialCenter: routePoints.isNotEmpty ? routePoints[0] : const LatLng(44.5646, -123.2620),
              initialZoom: 13.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://api.mapbox.com/styles/v1/mapbox/streets-v12/tiles/{z}/{x}/{y}?access_token={accessToken}',
                additionalOptions: {'accessToken': mapboxToken},
              ),
              if (routePoints.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: routePoints,
                      color: Colors.blue,
                      strokeWidth: 5.0,
                    ),
                  ],
                ),
              if (routePoints.isNotEmpty)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: routePoints.first,
                      child: const Icon(Icons.location_on, color: Colors.green, size: 30),
                    ),
                    Marker(
                      point: routePoints.last,
                      child: const Icon(Icons.flag, color: Colors.red, size: 30),
                    ),
                  ],
                ),
            ],
          ),
          
          // Sliding Directions Panel
          if (!isLoading && steps.isNotEmpty)
            DraggableScrollableSheet(
              initialChildSize: 0.3,
              minChildSize: 0.2,
              maxChildSize: 0.7,
              builder: (context, scrollController) {
                return Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                    boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10)],
                  ),
                  child: Column(
                    children: [
                      // Drag handle
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Icon(Icons.maximize, color: Colors.grey, size: 40),
                        ),
                      ),
                      
                      // Duration and Arrival Time Info Card
                      if (totalDuration.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.blue.shade100),
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Total Duration',
                                          style: TextStyle(fontSize: 12, color: Colors.grey),
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            const Icon(Icons.access_time, size: 16, color: Colors.blue),
                                            const SizedBox(width: 4),
                                            Text(
                                              totalDuration,
                                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    width: 1,
                                    height: 40,
                                    color: Colors.grey.shade300,
                                  ),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Arrival Time',
                                          style: TextStyle(fontSize: 12, color: Colors.grey),
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            const Icon(Icons.schedule, size: 16, color: Colors.green),
                                            const SizedBox(width: 4),
                                            Text(
                                              arrivalTime,
                                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              // Show traffic delay if present
                              if (trafficDelay != null && widget.transportMode == 'drive')
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.traffic, size: 14, color: Colors.orange),
                                      const SizedBox(width: 4),
                                      Text(
                                        '⚠️ Traffic delay: +$trafficDelay',
                                        style: const TextStyle(fontSize: 12, color: Colors.orange),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      
                      // Directions list - only showing distance, no duration
                      Expanded(
                        child: ListView.builder(
                          controller: scrollController,
                          itemCount: steps.length,
                          itemBuilder: (context, index) {
                            final step = steps[index];
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Colors.blue.shade50,
                                child: Text("${step.stepNumber}"),
                              ),
                              title: Text(step.instruction),
                              subtitle: Text(step.distance), // Only showing distance
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),

          if (isLoading)
            const Center(child: CircularProgressIndicator()),
          if (errorMessage != null)
            Center(
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.all(20),
                child: Text(errorMessage!),
              ),
            ),
        ],
      ),
    );
  }
}

// DirectionStep class without duration field
class DirectionStep {
  final String instruction;
  final String distance;
  final int stepNumber;

  DirectionStep({
    required this.instruction,
    required this.distance,
    required this.stepNumber,
  });
}
