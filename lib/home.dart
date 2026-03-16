import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'alertdetails.dart';
import 'models/local_alert.dart';
import '/services/notification_service.dart';
import 'services/api_service.dart';

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
  bool _isLoading = false; 
  
  StreamSubscription<Position>? _positionStream;
  Timer? _pollingTimer;

  // --- Mock Data ---
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
      hazardType: "medical_emergency",
      title: "Medical Emergency",
      description: "Ambulance on site near the medical center.",
      icon: Icons.add_box,
      color: Colors.green,
    ),
    LocalAlert(
      position: const LatLng(44.553, -123.270),
      hazardType: "severe_weather",
      title: "General Warning",
      description: "Caution: Slippery conditions in Avery Park.",
      icon: Icons.warning,
      color: Colors.amber,
    ),
    LocalAlert(
      position: const LatLng(44.560, -123.255),
      hazardType: "road_closure",
      title: "Traffic Incident",
      description: "Road work causing delays on Highway 99.",
      icon: Icons.directions_car,
      color: Colors.purple,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _alerts = List.from(_mockAlerts); 
    NotificationService().initialize(); 
    _startLocationUpdates();
    _fetchAlerts(); 
    _pollingTimer = Timer.periodic(const Duration(seconds: 60), (_) => _fetchAlerts());

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final LatLng? navTarget = ModalRoute.of(context)?.settings.arguments as LatLng?;
      if (navTarget != null) {
        mapController.move(navTarget, 15.0);
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

  Future<void> _fetchAlerts() async {
    final String baseUrl = 'https://guardianly-backend-34405523525.us-west1.run.app';
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
              // Combine real alerts with mock alerts
              final realAlerts = fetchedNotifications.map((json) => LocalAlert.fromJson(json)).toList();
              _alerts = [...realAlerts, ..._mockAlerts];
            });
          }
        }
      } else {
        _fallbackToMocks();
      }
    } catch (e) {
      debugPrint("Error fetching alerts: $e");
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

  void _getAIAdvice() {
    debugPrint("AI Advice requested");
  }

  void _showReportDialog(LatLng location) {
    final titleController = TextEditingController();
    final messageController = TextEditingController();
    String selectedType = 'general';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Report Danger at This Location'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(hintText: 'Alert Title (e.g. Fire)'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: messageController,
                decoration: const InputDecoration(hintText: 'Description'),
              ),
              const SizedBox(height: 10),
              DropdownButton<String>(
                value: selectedType,
                isExpanded: true,
                items: const [
                  DropdownMenuItem(value: 'general', child: Text('General')),
                  DropdownMenuItem(value: 'wildfire', child: Text('Fire')),
                  DropdownMenuItem(value: 'police_activity', child: Text('Police')),
                  DropdownMenuItem(value: 'medical_emergency', child: Text('Medical')),
                ],
                onChanged: (val) => setDialogState(() => selectedType = val!),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (titleController.text.isEmpty || messageController.text.isEmpty) return;

                final success = await ApiService.reportAlert(
                  title: titleController.text,
                  message: messageController.text,
                  hazardType: selectedType, // FIXED: Added missing hazardType argument
                  lat: location.latitude,
                  lng: location.longitude,
                );

                if (mounted) {
                  Navigator.pop(context);
                  if (success) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Alert reported!")));
                    _fetchAlerts();
                  }
                }
              },
              child: const Text('Report'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAlertDetails(LocalAlert alert) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AlertDetails(
          hazardType: alert.hazardType,
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
                        onLongPress: (tapPosition, latLng) {
                          _showReportDialog(latLng);
                        },
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
                  
                  if (_isLoading)
                    Container(
                      color: Colors.black.withValues(alpha: 0.1),
                      child: const Center(child: CircularProgressIndicator()),
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
