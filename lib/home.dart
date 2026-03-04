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
import '/services/notification_service.dart';
// import '/services/api_service.dart';

// Components
import '/Components/searchbar.dart';
import '/Components/menu.dart';
import '/Components/key.dart';

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
    
    // 1. Initialize data
    _alerts = _mockAlerts; 

    // 2. Request Push Notification permissions & save token
    NotificationService().initialize(); 
    
    // 3. Start GPS tracking
    _startLocationUpdates();
    
    // 4. Fetch the live hazards from backend
    _fetchAlerts(); 
    
    // 5. Set up Polling (every 60 seconds)
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
      // Get the base URL from your .env file (e.g., your Cloud Run URL or http://10.0.2.2:5000 for local Android)
      final String baseUrl = 'https://guardianly-backend-34405523525.us-west1.run.app';
      // final String baseUrl = ApiService.baseUrl;
      if (baseUrl.isEmpty) {
        debugPrint("Warning: API_URL not found");
        return;
      }

      final String apiUrl = "$baseUrl/api/notifications";

      try {
        // 1. Get the current user's Firebase token
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) {
          debugPrint("User not logged in, cannot fetch alerts.");
          return;
        }
        final token = await user.getIdToken();

        // 2. Make the authenticated GET request
        final response = await http.get(
          Uri.parse(apiUrl),
          headers: {
            'Authorization': 'Bearer $token', // Required by server.py @token_required
            'Content-Type': 'application/json',
          },
        );

      // 3. Parse and map the response
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
      } else {
        debugPrint("Failed to fetch alerts. Status Code: ${response.statusCode}");
        _fallbackToMocks();
      }
    } catch (e) {
      debugPrint("Error fetching alerts: $e");
      _fallbackToMocks();
    }
  }

  // Helper method to keep your map populated if the server is offline during dev
  void _fallbackToMocks() {
    if (mounted) {
      setState(() {
        _alerts = _mockAlerts; 
      });
    }
  }

  // --- UI: Alert Modal ---
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