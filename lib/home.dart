import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '/Components/searchbar.dart';
import '/Components/menu.dart';
import '/Components/key.dart';

class LocalAlert {
  final LatLng position;
  final String title;
  final String description;
  final IconData icon;
  final Color color;

  LocalAlert({
    required this.position,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
  });
}

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => HomeState();
}

class HomeState extends State<Home> {
  final MapController mapController = MapController();
  bool showKeyBox = false;
  LatLng? _currentP;

  // Mock alerts in Corvallis matching the Map Legend
  final List<LocalAlert> _mockAlerts = [
    LocalAlert(
      position: const LatLng(44.567, -123.278),
      title: "Fire Alert",
      description: "Small brush fire reported near the stadium.",
      icon: Icons.local_fire_department,
      color: Colors.red,
    ),
    LocalAlert(
      position: const LatLng(44.564, -123.261),
      title: "Police Presence",
      description: "Police investigating a minor incident downtown.",
      icon: Icons.security,
      color: Colors.blue,
    ),
    LocalAlert(
      position: const LatLng(44.588, -123.275),
      title: "Medical Emergency",
      description: "Ambulance on site near the medical center.",
      icon: Icons.add_box,
      color: Colors.green,
    ),
    LocalAlert(
      position: const LatLng(44.553, -123.270),
      title: "General Warning",
      description: "Caution: Slippery conditions in Avery Park.",
      icon: Icons.warning,
      color: Colors.amber,
    ),
    LocalAlert(
      position: const LatLng(44.560, -123.255),
      title: "Traffic Incident",
      description: "Road work causing delays on Highway 99.",
      icon: Icons.directions_car,
      color: Colors.purple,
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

    try {
      Position position = await Geolocator.getCurrentPosition();
      setState(() {
        _currentP = LatLng(position.latitude, position.longitude);
      });

      if (_currentP != null) {
        mapController.move(_currentP!, 15.0);
      }
    } catch (e) {
      debugPrint("Error getting location: $e");
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
                  Icon(alert.icon, color: alert.color, size: 28),
                  const SizedBox(width: 10),
                  Text(
                    alert.title,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 15),
              Text(alert.description, style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.black),
                  child: const Text("Dismiss", style: TextStyle(color: Colors.white)),
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
          const SearchBarApp(isOnAlertPage: false),
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
                        initialCenter: _currentP ?? const LatLng(44.5646, -123.2620),
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
                        if (_currentP != null)
                          MarkerLayer(
                            markers: [
                              Marker(
                                point: _currentP!,
                                width: 40,
                                height: 40,
                                child: const Icon(Icons.person_pin_circle, color: Colors.blue, size: 40),
                              ),
                            ],
                          ),
                        // Mock alerts MarkerLayer
                        MarkerLayer(
                          markers: _mockAlerts.map((alert) {
                            return Marker(
                              point: alert.position,
                              width: 40,
                              height: 40,
                              child: GestureDetector(
                                onTap: () => _showAlertDetails(alert),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.2),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Icon(alert.icon, color: alert.color, size: 28),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                  const Positioned(
                    bottom: 16,
                    left: 16,
                    child: MapKey(),
                  ),
                  Positioned(
                    bottom: 16,
                    right: 16,
                    child: FloatingActionButton(
                      mini: true,
                      onPressed: _getLocation,
                      backgroundColor: Colors.white,
                      child: const Icon(Icons.my_location, color: Colors.blue),
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
