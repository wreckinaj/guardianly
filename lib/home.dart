import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import '/alertdetails.dart';
import '/models/local_alert.dart';
// import '/services/api_service.dart';

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
      description: json['message'] ?? '',
      icon: Icons.warning, 
      color: Colors.red,   
    );
  }
}

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => HomeState();
}

class HomeState extends State<Home> {
  final MapController mapController = MapController();
  final String mapboxToken = dotenv.env['MAPBOX_ACCESS_TOKEN'] ?? '';
  
  LatLng? _currentP;
  List<LocalAlert> _alerts = [];
  
  StreamSubscription<Position>? _positionStream;
  Timer? _pollingTimer;

  final List<LocalAlert> _mockAlerts = [
    LocalAlert(
      position: const LatLng(44.567, -123.278),
      title: "Fire Alert",
      description: "Small brush fire reported near the stadium.",
      hazardType: "wildfire",
      icon: Icons.local_fire_department,
      color: Colors.red,
    ),
    LocalAlert(
      position: const LatLng(44.564, -123.261),
      title: "Police Presence",
      description: "Police investigating a minor incident downtown.",
      hazardType: "police_activity",
      icon: Icons.security,
      color: Colors.blue,
    ),
    LocalAlert(
      position: const LatLng(44.588, -123.275),
      title: "Medical Emergency",
      description: "Ambulance on site near the medical center.",
      hazardType: "severe_weather",
      icon: Icons.add_box,
      color: Colors.green,
    ),
    LocalAlert(
      position: const LatLng(44.553, -123.270),
      title: "General Warning",
      description: "Caution: Slippery conditions in Avery Park.",
      hazardType: "road_closure",
      icon: Icons.warning,
      color: Colors.amber,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _alerts = List.from(_mockAlerts); 
    _startLocationUpdates();
    _fetchAlerts(); 
    _pollingTimer = Timer.periodic(const Duration(seconds: 60), (_) => _fetchAlerts());

    // Check for passed navigation arguments (from alert list)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final LatLng? navTarget = ModalRoute.of(context)?.settings.arguments as LatLng?;
      if (navTarget != null) {
        mapController.move(navTarget, 15.0);
        // Find the alert to show details
        final alert = _alerts.firstWhere((a) => a.position == navTarget, orElse: () => _alerts.first);
        _showAlertDetails(alert);
      }
    });
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _pollingTimer?.cancel();
    mapController.dispose();
    super.dispose();
  }

  Future<void> _startLocationUpdates() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    if (permission == LocationPermission.deniedForever) return;

    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10, 
    );

    _positionStream = Geolocator.getPositionStream(locationSettings: locationSettings)
        .listen((Position position) {
      if (mounted) {
        setState(() {
          _currentP = LatLng(position.latitude, position.longitude);
        });
        _checkProximityToHazards(position);
      }
    });
  }

  void _checkProximityToHazards(Position userPos) {
    for (var alert in _alerts) {
      double distanceInMeters = Geolocator.distanceBetween(
        userPos.latitude,
        userPos.longitude,
        alert.position.latitude,
        alert.position.longitude,
      );

      if (distanceInMeters < 500) {
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
              onPressed: () {
                mapController.move(alert.position, 15.0);
                _showAlertDetails(alert);
              },
            ),
          ),
        );
      }
    }
  }

  // --- Logic: Fetch Alerts from Backend ---
   Future<void> _fetchAlerts() async {
      // Get the base URL from your .env file (e.g., your Cloud Run URL or http://10.0.2.2:5000 for local Android)
      final String baseUrl = 'https://guardianly-backend-34405523525.us-west1.run.app';
      // final String baseUrl = ApiService.baseUrl;
      if (baseUrl.isEmpty) {
        debugPrint("Warning: API_URL not found");
        return;
      }

      final String apiUrl = "$baseUrl/api/notifications";

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final token = await user.getIdToken();

      final response = await http.get(
        Uri.parse(apiUrl),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);

          if (data['status'] == 'success') {
            final List<dynamic> fetchedNotifications = data['notifications'];
            if (mounted) {
              setState(() {
                _alerts = fetchedNotifications.map((json) {
                  // Map the backend JSON to your LocalAlert model
                  return LocalAlert(
                    // NOTE: Your backend doesn't save lat/lng yet, using fallback coordinates
                    position: LatLng(json['lat'] ?? 44.564, json['lng'] ?? -123.261), 
                    title: json['title'] ?? 'Alert',
                    description: json['message'] ?? '',
                    hazardType: json['hazardType'] ?? 'general',
                    icon: Icons.warning, 
                    color: Colors.red,
                  );
                }).toList();
              });
            }
          }
        }
      } else {
        _fallbackToMocks();
      }
    } catch (e) {
      _fallbackToMocks();
    }
  }

  void _fallbackToMocks() {
    if (mounted) {
      setState(() {
        _alerts = List.from(_mockAlerts); 
      });
    }
  }

  void _showAlertDetails(LocalAlert alert) {
    // Instead of a simple bottom sheet, push the full AlertDetails screen!
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AlertDetails(
          hazardType: alert.hazardType, // Passes 'wildfire', etc. to the AI
          lat: alert.position.latitude,
          lng: alert.position.longitude,
          title: alert.title,
          locationName: alert.description, 
        ),
      ),
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
