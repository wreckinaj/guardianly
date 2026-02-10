import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '/Components/searchbar.dart';
import '/Components/menu.dart';
import 'alertdetails.dart';
import 'services/api_service.dart';

// A simple class to represent an Alert localized for now
class LocalAlert {
  final LatLng position;
  final String title;
  final String description;

  LocalAlert({
    required this.position,
    required this.title,
    required this.description,
  });
}

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  final MapController mapController = MapController();
  LatLng? _currentP;
  bool _isLoading = false;

  // Localized mock data for alerts - Updated to Corvallis, OR
  final List<LocalAlert> _mockAlerts = [
    LocalAlert(
      position: const LatLng(44.568, -123.270), // Example: Near OSU campus
      title: "Suspicious Activity",
      description: "Reports of suspicious behavior near the park entrance.",
    ),
    LocalAlert(
      position: const LatLng(44.560, -123.250), // Near Corvallis downtown
      title: "Construction Hazard",
      description: "Falling debris reported near the construction site.",
    ),
  ];

  @override
  void initState() {
    super.initState();
    _getLocation();
  }

  Future<void> _getLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    if (permission == LocationPermission.deniedForever) return;

    Position position = await Geolocator.getCurrentPosition();
    setState(() {
      _currentP = LatLng(position.latitude, position.longitude);

      // Optionally add a mock alert right where the user is for testing
      _mockAlerts.add(LocalAlert(
        position: LatLng(position.latitude + 0.002, position.longitude + 0.002),
        title: "Recent Report",
        description: "An alert was recently reported near your location.",
      ));
    });

    if (_currentP != null) {
      mapController.move(_currentP!, 15.0);
    }
  }

  // --- NEW: AI Integration Function ---
  void _getAIAdvice() async {
    if (_currentP == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Waiting for location...")),
      );
      return;
    }

    setState(() => _isLoading = true);

    // Call the backend service
    final result = await ApiService.generateSafetyAlert(
      hazardType: "General Safety Check", // You can make this dynamic later
      lat: _currentP!.latitude,
      lng: _currentP!.longitude,
    );

    setState(() => _isLoading = false);

    if (!mounted) return;

    if (result != null) {
      // Show the AI Response
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(
                Icons.shield,
                color: result.severity == 'High' ? Colors.red : Colors.orange,
              ),
              const SizedBox(width: 8),
              Text("${result.severity} Alert"),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  result.message,
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 15),
                const Text(
                  "Recommended Actions:",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 5),
                ...result.actions.map((action) => Padding(
                      padding: const EdgeInsets.only(bottom: 4.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("• "),
                          Expanded(child: Text(action)),
                        ],
                      ),
                    )),
                const SizedBox(height: 15),
                Text(
                  "Source: ${result.source}",
                  style: const TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: Colors.grey),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("OK"),
            ),
          ],
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Could not connect to AI Safety System.")),
      );
    }
  }

  void _showAlertDetails(LocalAlert alert) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.local_fire_department,
                      color: Colors.red, size: 28),
                  const SizedBox(width: 10),
                  Text(
                    alert.title,
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 15),
              Text(
                alert.description,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style:
                      ElevatedButton.styleFrom(backgroundColor: Colors.black),
                  child: const Text("Dismiss",
                      style: TextStyle(color: Colors.white)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const Menu(),
      body: Column(
        children: [
          const SearchBarApp(),
          const SizedBox(height: 16),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24.0, 0.0, 24.0, 32.0),
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: FlutterMap(
                      mapController: mapController,
                      options: MapOptions(
                        initialCenter: _currentP ??
                            const LatLng(44.5646, -123.2620), // Default to Corvallis
                        initialZoom: 14.0,
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              'https://api.mapbox.com/styles/v1/mapbox/streets-v12/tiles/{z}/{x}/{y}?access_token={accessToken}',
                          additionalOptions: const {
                            'accessToken':
                                'pk.eyJ1Ijoic2hvb2tkIiwiYSI6ImNtaG9mNXE3ajBhbGYycXBzYmpsN2ppanEifQ.Zw3YIGnVLC9K36olfWBI6A',
                          },
                        ),
                        // Marker Layer for User Location
                        if (_currentP != null)
                          MarkerLayer(
                            markers: [
                              Marker(
                                point: _currentP!,
                                width: 40,
                                height: 40,
                                child: const Icon(
                                  Icons.person_pin_circle,
                                  color: Colors.blue,
                                  size: 40,
                                ),
                              ),
                            ],
                          ),
                        // Marker Layer for Danger/Alert points
                        MarkerLayer(
                          markers: _mockAlerts.map((alert) {
                            return Marker(
                              point: alert.position,
                              width: 40,
                              height: 40,
                              child: GestureDetector(
                                onTap: () => _showAlertDetails(alert),
                                child: const Icon(
                                  Icons.local_fire_department,
                                  color: Colors.red,
                                  size: 40,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),

                  // Loading Indicator Overlay
                  if (_isLoading)
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Center(
                        child:
                            CircularProgressIndicator(color: Colors.white),
                      ),
                    ),

                  // "Key" Button and "AI Check" Button (Bottom Left)
                  Positioned(
                    bottom: 16,
                    left: 16,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // NEW: AI Safety Check Button
                        ElevatedButton.icon(
                          onPressed: _getAIAdvice,
                          icon: const Icon(Icons.security, size: 18),
                          label: const Text('AI Check'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            elevation: 2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Existing Key Button
                        ElevatedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => const AlertDetails()),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.red,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            elevation: 2,
                          ),
                          child: const Text(
                            'Key',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // My Location Button (Bottom Right)
                  Positioned(
                    bottom: 16,
                    right: 16,
                    child: FloatingActionButton(
                      mini: true,
                      onPressed: _getLocation,
                      backgroundColor: Colors.white,
                      child:
                          const Icon(Icons.my_location, color: Colors.blue),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}