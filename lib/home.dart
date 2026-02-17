import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

// Components
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

  // Factory to create from JSON (ready for backend integration)
  factory LocalAlert.fromJson(Map<String, dynamic> json) {
    return LocalAlert(
      position: LatLng(
        json['lat'] ?? 0.0, 
        json['lng'] ?? 0.0
      ),
      title: json['title'] ?? 'Alert',
      description: json['description'] ?? '',
      icon: Icons.warning, // You might map string types to Icons here
      color: Colors.red,   // You might map severity to Colors here
    );
  }
}

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => HomeState();
}

class HomeState extends State<Home> {
  // --- State Variables ---
  final MapController mapController = MapController();
  final String mapboxToken = dotenv.env['MAPBOX_ACCESS_TOKEN'] ?? '';
  
  LatLng? _currentP;
  List<LocalAlert> _alerts = [];
  
  // Async & Streams
  StreamSubscription<Position>? _positionStream;
  Timer? _pollingTimer;

  // --- Mock Data (Fallback) ---
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
    // 1. Initialize data
    _alerts = _mockAlerts; // Start with mocks, then fetch real data
    
    // 2. Start Services
    _startLocationUpdates();
    _fetchAlerts(); 
    
    // 3. Set up Polling (every 60 seconds)
    _pollingTimer = Timer.periodic(const Duration(seconds: 60), (_) => _fetchAlerts());
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _pollingTimer?.cancel();
    mapController.dispose();
    super.dispose();
  }

  // --- Logic: Location Tracking ---
  Future<void> _startLocationUpdates() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Check Service
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    // Check Permissions
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    if (permission == LocationPermission.deniedForever) return;

    // Start Stream
    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10, // Only update if moved 10 meters
    );

    _positionStream = Geolocator.getPositionStream(locationSettings: locationSettings)
        .listen((Position position) {
      
      setState(() {
        _currentP = LatLng(position.latitude, position.longitude);
      });

      // Move map only on first fix or valid update (optional)
      // mapController.move(_currentP!, 15.0); 

      // Check proximity to any active alerts
      _checkProximityToHazards(position);
    });
  }

  // --- Logic: Alert Proximity ---
  void _checkProximityToHazards(Position userPos) {
    for (var alert in _alerts) {
      double distanceInMeters = Geolocator.distanceBetween(
        userPos.latitude,
        userPos.longitude,
        alert.position.latitude,
        alert.position.longitude,
      );

      // Warning Threshold: 500 meters
      if (distanceInMeters < 500) {
        // Debounce logic could go here to prevent spamming
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "WARNING: Approaching ${alert.title} (${distanceInMeters.toStringAsFixed(0)}m)",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            backgroundColor: alert.color,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'VIEW',
              textColor: Colors.white,
              onPressed: () => _showAlertDetails(alert),
            ),
          ),
        );
      }
    }
  }

  // --- Logic: Fetch Alerts from Backend ---
  Future<void> _fetchAlerts() async {
    // TODO: Replace with your actual backend URL
    // final String apiUrl = "${dotenv.env['API_URL']}/api/alerts";
    
    try {
      // NOTE: When ready for real backend:
      // 1. Add 'package:http/http.dart' as http;
      // 2. Add 'dart:convert';
      // 3. Uncomment the lines below:

      // final response = await http.get(Uri.parse(apiUrl));
      // if (response.statusCode == 200) {
      //   final List<dynamic> data = json.decode(response.body);
      //   setState(() {
      //     _alerts = data.map((json) => LocalAlert.fromJson(json)).toList();
      //   });
      // }
      
      // Simulate network delay then refresh mocks
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) {
        setState(() {
          _alerts = _mockAlerts; // Reset to mocks for demo
        });
      }
    } catch (e) {
      debugPrint("Error fetching alerts: $e");
    }
  }

  // --- UI: Alert Modal ---
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

  // --- UI: Build ---
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
                        // Prevent rotation for simpler navigation UI
                        interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              'https://api.mapbox.com/styles/v1/mapbox/streets-v12/tiles/{z}/{x}/{y}?access_token={accessToken}',
                          additionalOptions: {
                            'accessToken': mapboxToken,
                          },
                        ),
                        // User Location Marker
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
                        // Hazard Markers
                        MarkerLayer(
                          markers: _alerts.map((alert) {
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
                                        color: Colors.black.withValues(alpha: 0.2),
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
                  // Map Legend / Key
                  const Positioned(
                    bottom: 16,
                    left: 16,
                    child: MapKey(),
                  ),
                  // Recenter Button
                  Positioned(
                    bottom: 16,
                    right: 16,
                    child: FloatingActionButton(
                      mini: true,
                      onPressed: () {
                         if (_currentP != null) {
                           mapController.move(_currentP!, 15.0);
                         }
                      },
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