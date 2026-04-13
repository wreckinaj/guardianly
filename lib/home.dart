import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'alertdetails.dart';
import 'models/local_alert.dart';
import '/services/notification_service.dart';

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
  final MapController mapController = MapController();
  final String mapboxToken = dotenv.env['MAPBOX_ACCESS_TOKEN'] ?? '';
  
  LatLng? _currentP;
  List<LocalAlert> _alerts = []; // Only holds database alerts now
  bool _isLoading = false; 
  
  StreamSubscription<Position>? _positionStream;
  StreamSubscription<QuerySnapshot>? _alertsSubscription;

  @override
  void initState() {
    super.initState();
    _initAsync();
  }

  Future<void> _initAsync() async {
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }
      
      NotificationService().initialize(); 
      _startLocationUpdates();
      _listenToDatabaseAlerts();

      // Handle navigation arguments from alert list
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final LatLng? navTarget = ModalRoute.of(context)?.settings.arguments as LatLng?;
        if (navTarget != null) {
          mapController.move(navTarget, 15.0);
        }
      });
    } catch (e) {
      debugPrint("Initialization failed: $e");
    }
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _alertsSubscription?.cancel();
    mapController.dispose();
    super.dispose();
  }

  /// Real-time Firestore listener: FETCHES FROM DB ONLY
  void _listenToDatabaseAlerts() {
    _alertsSubscription = FirebaseFirestore.instance
        .collection('alerts')
        .snapshots()
        .listen((snapshot) {
      debugPrint("Database updated: ${snapshot.docs.length} alerts found.");
      
      final dbAlerts = snapshot.docs.map((doc) {
        return LocalAlert.fromJson(doc.data() as Map<String, dynamic>);
      }).toList();

      if (mounted) {
        setState(() {
          _alerts = dbAlerts; // No more mock alerts here
        });
      }
    }, onError: (error) {
      debugPrint("Firestore Error: $error");
    });
  }

  Future<void> _startLocationUpdates() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 10)
    ).listen((Position position) {
      if (mounted) {
        setState(() => _currentP = LatLng(position.latitude, position.longitude));
        _checkProximityToHazards(position);
      }
    });
  }

  void _checkProximityToHazards(Position userPos) {
    for (var alert in _alerts) {
      double distance = Geolocator.distanceBetween(
        userPos.latitude, userPos.longitude,
        alert.position.latitude, alert.position.longitude,
      );

      if (distance < 500) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("WARNING: Approaching ${alert.title}"),
            backgroundColor: alert.color,
            action: SnackBarAction(label: 'VIEW', textColor: Colors.white, onPressed: () {
              mapController.move(alert.position, 15.0);
              _showAlertDetails(alert);
            }),
          ),
        );
      }
    }
  }

  void _showReportDialog(LatLng location) {
    final titleController = TextEditingController();
    final messageController = TextEditingController();
    String selectedType = 'general';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Report Danger'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: titleController, decoration: const InputDecoration(hintText: 'Title')),
              TextField(controller: messageController, decoration: const InputDecoration(hintText: 'Description')),
              DropdownButton<String>(
                value: selectedType,
                items: const [
                  DropdownMenuItem(value: 'general', child: Text('General')),
                  DropdownMenuItem(value: 'wildfire', child: Text('Fire')),
                  DropdownMenuItem(value: 'police_activity', child: Text('Police')),
                ],
                onChanged: (val) => setDialogState(() => selectedType = val!),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () async {
                await FirebaseFirestore.instance.collection('alerts').add({
                  'title': titleController.text,
                  'message': messageController.text,
                  'hazardType': selectedType,
                  'lat': location.latitude,
                  'lng': location.longitude,
                  'timestamp': FieldValue.serverTimestamp(),
                });
                Navigator.pop(context);
              },
              child: const Text('Report'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAlertDetails(LocalAlert alert) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => AlertDetails(
      hazardType: alert.hazardType,
      lat: alert.position.latitude,
      lng: alert.position.longitude,
      title: alert.title,
      locationName: alert.description, 
    )));
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
            child: Stack(
              children: [
                FlutterMap(
                  mapController: mapController,
                  options: MapOptions(
                    initialCenter: _currentP ?? const LatLng(44.5646, -123.2620),
                    initialZoom: 14.0,
                    onLongPress: (tapPosition, latLng) => _showReportDialog(latLng),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://api.mapbox.com/styles/v1/mapbox/streets-v12/tiles/{z}/{x}/{y}?access_token={accessToken}',
                      additionalOptions: {'accessToken': mapboxToken},
                    ),
                    if (_currentP != null)
                      MarkerLayer(markers: [
                        Marker(point: _currentP!, width: 40, height: 40, child: const Icon(Icons.person_pin_circle, color: Colors.blue, size: 40)),
                      ]),
                    MarkerLayer(
                      markers: _alerts.map((alert) => Marker(
                        point: alert.position,
                        width: 40, height: 40,
                        child: GestureDetector(
                          onTap: () => _showAlertDetails(alert),
                          child: Container(
                            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                            child: Icon(alert.icon, color: alert.color, size: 28),
                          ),
                        ),
                      )).toList(),
                    ),
                  ],
                ),
                const Positioned(bottom: 16, left: 16, child: MapKey()),
                Positioned(bottom: 16, right: 16, child: FloatingActionButton(
                  mini: true, onPressed: () { if (_currentP != null) mapController.move(_currentP!, 15.0); },
                  backgroundColor: Colors.white, child: const Icon(Icons.my_location, color: Colors.blue),
                )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
