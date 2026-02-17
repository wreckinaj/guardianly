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
  // Using environment variable for security
  final String mapboxToken = dotenv.env['MAPBOX_ACCESS_TOKEN'] ?? '';
  
  List<LatLng> routePoints = [];
  List<DirectionStep> steps = []; // Real directions parsed from Mapbox
  bool isLoading = true;
  String? errorMessage;
  bool isPanelExpanded = true;

  @override
  void initState() {
    super.initState();
    calculateRoute();
  }

  Future<void> calculateRoute() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
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
      // Added steps=true to the URL to get turn-by-turn data
      final url = 'https://api.mapbox.com/directions/v5/mapbox/$mode/${startCoords.longitude},${startCoords.latitude};${endCoords.longitude},${endCoords.latitude}?geometries=geojson&steps=true&access_token=$mapboxToken';
      
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final route = data['routes'][0];
        final List coords = route['geometry']['coordinates'];
        
        // Parse the turn-by-turn steps
        final List legs = route['legs'];
        List<DirectionStep> parsedSteps = [];
        int stepCount = 1;

        for (var leg in legs) {
          for (var step in leg['steps']) {
            parsedSteps.add(DirectionStep(
              instruction: step['maneuver']['instruction'],
              distance: "${(step['distance'] * 0.000621371).toStringAsFixed(1)} mi", // Convert meters to miles
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
              initialChildSize: 0.1,
              minChildSize: 0.1,
              maxChildSize: 0.6,
              builder: (context, scrollController) {
                return Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                    boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10)],
                  ),
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: steps.length + 1,
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(8.0),
                            child: Icon(Icons.maximize, color: Colors.grey, size: 40),
                          ),
                        );
                      }
                      final step = steps[index - 1];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.blue.shade50,
                          child: Text("${step.stepNumber}"),
                        ),
                        title: Text(step.instruction),
                        subtitle: Text(step.distance),
                      );
                    },
                  ),
                );
              },
            ),

          if (isLoading)
            const Center(child: CircularProgressIndicator()),
          if (errorMessage != null)
            Center(child: Container(color: Colors.white, padding: const EdgeInsets.all(20), child: Text(errorMessage!))),
        ],
      ),
    );
  }
}

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
