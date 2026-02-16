import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '/Components/key.dart';

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
  // --- NEW FUNCTIONAL CODE ---
  final MapController mapController = MapController();
  final String mapboxToken = 'pk.eyJ1Ijoic2hvb2tkIiwiYSI6ImNtaG9mNXE3ajBhbGYycXBzYmpsN2ppanEifQ.Zw3YIGnVLC9K36olfWBI6A';
  
  List<LatLng> routePoints = [];
  bool isLoading = true;
  String? errorMessage;
  bool isPanelExpanded = true;

  /* --- ORIGINAL CODE (COMMENTED OUT) ---
  bool showDirections = true;
  TextEditingController fromController = TextEditingController();
  TextEditingController toController = TextEditingController();
  List<DirectionStep> directions = [];
  RouteSummary? routeSummary;
  bool isLoadingDirections = false;
  */

  @override
  void initState() {
    super.initState();
    calculateRoute();
    
    /* --- ORIGINAL INITSTATE (COMMENTED OUT) ---
    fromController.text = widget.fromLocation;
    toController.text = widget.toLocation;
    loadMockData();
    */
  }

  // --- NEW FUNCTIONAL METHODS ---
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
      final url = 'https://api.mapbox.com/directions/v5/mapbox/$mode/${startCoords.longitude},${startCoords.latitude};${endCoords.longitude},${endCoords.latitude}?geometries=geojson&access_token=$mapboxToken';
      
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List coords = data['routes'][0]['geometry']['coordinates'];
        
        setState(() {
          routePoints = coords.map((c) => LatLng(c[1].toDouble(), c[0].toDouble())).toList();
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

  /* --- ORIGINAL MOCK DATA METHOD (COMMENTED OUT) ---
  void loadMockData() {
    setState(() {
      directions = [
        DirectionStep(
          instruction: 'NW 19th St toward NW Tyler Ave',
          distance: '0.2 mi',
          duration: '3 min',
          arrivalTime: '9:33',
          turnIcon: Icons.straight,
          turnColor: Colors.blue,
          stepNumber: 1,
          isCurrent: true,
        ),
        DirectionStep(
          instruction: 'Turn left onto NW Tyler Ave',
          distance: '0.5 mi',
          duration: '2 min',
          arrivalTime: '9:35',
          turnIcon: Icons.turn_left,
          turnColor: Colors.orange,
          stepNumber: 2,
          isCurrent: false,
        ),
        DirectionStep(
          instruction: 'Turn right onto Main St',
          distance: '1.2 mi',
          duration: '5 min',
          arrivalTime: '9:40',
          turnIcon: Icons.turn_right,
          turnColor: Colors.green,
          stepNumber: 3,
          isCurrent: false,
        ),
        DirectionStep(
          instruction: 'Arrive at destination',
          distance: '',
          duration: '',
          arrivalTime: '',
          turnIcon: Icons.location_on,
          turnColor: Colors.red,
          stepNumber: 4,
          isCurrent: false,
        ),
      ];
      
      routeSummary = RouteSummary(
        totalDistance: '1.9 mi',
        totalDuration: '10 min',
        arrivalTime: '9:40 AM',
        startAddress: widget.fromLocation,
        endAddress: widget.toLocation,
      );
    });
  }
  */

  @override
  void dispose() {
    // fromController.dispose(); // Commented out original dispose
    // toController.dispose();
    mapController.dispose();
    super.dispose();
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
          if (isLoading)
            const Center(child: CircularProgressIndicator()),
          if (errorMessage != null)
            Center(child: Container(color: Colors.white, padding: const EdgeInsets.all(20), child: Text(errorMessage!))),
        ],
      ),
    );
  }

  /* --- ORIGINAL HELPER UI METHODS (COMMENTED OUT) ---
  Widget buildDirectionsPanel(double screenHeight, IconData transportIcon, String transportLabel) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      height: isPanelExpanded ? screenHeight * 0.45 : screenHeight * 0.08,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 12, spreadRadius: 2)],
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: () => setState(() => isPanelExpanded = !isPanelExpanded),
            child: Container(width: 40, height: 4, margin: const EdgeInsets.only(top: 12, bottom: 8), decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(2))),
          ),
          if (isPanelExpanded) Expanded(child: SingleChildScrollView(child: Column(...))), // Logic omitted for brevity but preserved in Git
        ],
      ),
    );
  }

  Widget buildSummaryItem(IconData icon, String label, String value) { ... }
  Widget buildDirectionStep(DirectionStep step) { ... }
  IconData getTransportIcon(String mode) { ... }
  String getTransportLabel(String mode) { ... }
  */
}

/* --- ORIGINAL CLASSES (COMMENTED OUT) ---
class DirectionStep {
  final String instruction;
  final String distance;
  final String duration;
  final String arrivalTime;
  final IconData turnIcon;
  final Color turnColor;
  final int stepNumber;
  final bool isCurrent;

  DirectionStep({required this.instruction, required this.distance, required this.duration, required this.arrivalTime, required this.turnIcon, required this.turnColor, required this.stepNumber, required this.isCurrent});
}

class RouteSummary {
  final String totalDistance;
  final String totalDuration;
  final String arrivalTime;
  final String startAddress;
  final String endAddress;

  RouteSummary({required this.totalDistance, required this.totalDuration, required this.arrivalTime, required this.startAddress, required this.endAddress});
}
*/
