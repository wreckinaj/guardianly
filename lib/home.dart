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
  List<LocalAlert> _alerts = [];
  
  StreamSubscription<Position>? _positionStream;
  StreamSubscription<QuerySnapshot>? _alertsSubscription;

  // List of hazards derived from mock_playbook filenames for the dropdown
  final List<String> _hazardOptions = [
    "flood", "building_fire", "wildfire", "hurricane", 
    "tornado", "active_shooter", "police_activity", 
    "road_closure", "severe_weather", "earthquake", 
    "hazmat_spill", "gas_leak", "volcanic_eruption", "tsunami",
    "power_outage", "icy_roads", "heavy_traffic", 
    "construction_zone", "low_visibility", "wildlife",
    "civil_unrest", "transit_disruption", "extreme_heat", "air_quality",
    "blizzard", "flooded_pathway",
    "suspicious_package", "sinkhole", "downed_power_lines"
  ];

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

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
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

  void _listenToDatabaseAlerts() {
    _alertsSubscription = FirebaseFirestore.instance
        .collection('alerts')
        .snapshots()
        .listen((snapshot) {
      final dbAlerts = snapshot.docs.map((doc) {
        return LocalAlert.fromJson(doc.data());
      }).toList();

      if (mounted) {
        setState(() {
          _alerts = dbAlerts;
        });
      }
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
    final messageController = TextEditingController();
    String selectedType = _hazardOptions[0]; 

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Report Danger'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Select Danger Type:", style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                DropdownButton<String>(
                  value: selectedType,
                  isExpanded: true,
                  items: _hazardOptions.map((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value.replaceAll('_', ' ').toUpperCase()),
                    );
                  }).toList(),
                  onChanged: (val) => setDialogState(() => selectedType = val!),
                ),
                const SizedBox(height: 16),
                const Text("Description (Optional):", style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                TextField(
                  controller: messageController,
                  decoration: const InputDecoration(
                    hintText: 'e.g. Near the main entrance',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                String alertTitle = selectedType.replaceAll('_', ' ').toUpperCase();
                
                await FirebaseFirestore.instance.collection('alerts').add({
                  'title': alertTitle,
                  'message': messageController.text,
                  'hazardType': selectedType,
                  'lat': location.latitude,
                  'lng': location.longitude,
                  'timestamp': FieldValue.serverTimestamp(),
                  'reportedBy': FirebaseAuth.instance.currentUser?.uid,
                });
                if (mounted) {
                  Navigator.pop(context);
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
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 4, offset: const Offset(0, 2))],
                                ),
                                child: Icon(alert.icon, color: alert.color, size: 28),
                              ),
                            ),
                          )).toList(),
                        ),
                      ],
                    ),
                  ),
                  const Positioned(bottom: 16, left: 16, child: MapKey()),
                  Positioned(bottom: 16, right: 16, child: FloatingActionButton(
                    mini: true, onPressed: () { if (_currentP != null) mapController.move(_currentP!, 15.0); },
                    backgroundColor: Colors.white, child: const Icon(Icons.my_location, color: Colors.blue),
                  )),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
