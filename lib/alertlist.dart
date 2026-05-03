import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'Components/searchbar.dart';
import '/Components/menu.dart';
import 'alertdetails.dart';
import 'models/local_alert.dart';
import 'saved_alerts_provider.dart';

class Alert extends StatefulWidget {
  const Alert({super.key});

  @override
  State<Alert> createState() => _AlertState();
}

class _AlertState extends State<Alert> {
  SharedPreferences? _prefs;
  bool _isLoading = true;
  
  @override
  void initState() {
    super.initState();
    _loadSettings();
  }
  
  Future<void> _loadSettings() async {
    _prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  // Check if an alert type is enabled in settings
  bool isAlertEnabled(String hazardType) {
    if (_prefs == null) return true; // Default to true if settings not loaded
    
    switch (hazardType) {
      case 'wildfire':
        return _prefs!.getBool('wildfireAlerts') ?? true;
      case 'police_activity':
        return _prefs!.getBool('policeActivityAlerts') ?? true;
      case 'medical_emergency':
        return _prefs!.getBool('medicalEmergencyAlerts') ?? true;
      case 'severe_weather':
        return _prefs!.getBool('severeWeatherAlerts') ?? true;
      case 'road_closure':
        return _prefs!.getBool('roadClosureAlerts') ?? true;
      default:
        return true; // Show unknown alert types by default
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: const Menu(),
      body: Column(
        children: [
          const SearchBarApp(isOnAlertPage: true),
          const SizedBox(height: 16),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('alerts')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(child: Text("Error loading alerts"));
                }
                if (snapshot.connectionState == ConnectionState.waiting || _isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data!.docs;
                if (docs.isEmpty) {
                  return const Center(child: Text("No active alerts found."));
                }

                // Filter alerts based on user settings
                final filteredDocs = docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final hazardType = data['hazardType'] as String? ?? '';
                  return isAlertEnabled(hazardType);
                }).toList();

                if (filteredDocs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.notifications_off, size: 64, color: Colors.grey),
                        const SizedBox(height: 16),
                        const Text(
                          'No alerts match your preferences',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () {
                            Navigator.pushNamed(context, '/settings');
                          },
                          child: const Text('Adjust Alert Settings'),
                        ),
                      ],
                    ),
                  );
                }

                // Sort filtered alerts
                final sortedDocs = List.from(filteredDocs);
                sortedDocs.sort((a, b) {
                  final aData = a.data() as Map<String, dynamic>;
                  final bData = b.data() as Map<String, dynamic>;
                  final aTime = aData['timestamp'] as Timestamp?;
                  final bTime = bData['timestamp'] as Timestamp?;
                  if (aTime == null) return 1;
                  if (bTime == null) return -1;
                  return bTime.compareTo(aTime);
                });

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: sortedDocs.length,
                  itemBuilder: (context, index) {
                    final data = sortedDocs[index].data() as Map<String, dynamic>;
                    final alert = LocalAlert.fromJson(data);
                    
                    // Use Consumer to listen to saved alerts changes
                    return Consumer<SavedAlertsProvider>(
                      builder: (context, savedProvider, child) {
                        final isSaved = savedProvider.isAlertSaved(alert);
                        
                        return Container(
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withValues(alpha: 0.2),
                                blurRadius: 5,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    margin: const EdgeInsets.only(top: 4, right: 12),
                                    decoration: BoxDecoration(
                                      color: alert.color.withValues(alpha: 0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(alert.icon, color: alert.color, size: 24),
                                  ),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          alert.title,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black87,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          alert.description,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            color: Colors.black54,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: Icon(
                                      isSaved ? Icons.bookmark : Icons.bookmark_border,
                                      color: isSaved ? Colors.black : Colors.grey,
                                    ),
                                    onPressed: () {
                                      savedProvider.toggleSaveAlert(alert);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            isSaved 
                                              ? 'Removed from saved alerts' 
                                              : 'Saved to bookmarks',
                                          ),
                                          duration: const Duration(seconds: 1),
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                              const Divider(height: 24),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: [
                                  TextButton.icon(
                                    onPressed: () {
                                      Navigator.pushNamedAndRemoveUntil(
                                        context,
                                        '/home',
                                        (route) => false,
                                        arguments: alert.position,
                                      );
                                    },
                                    icon: const Icon(Icons.map, size: 18),
                                    label: const Text("VIEW ON MAP"),
                                  ),
                                  TextButton.icon(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => AlertDetails(
                                            hazardType: alert.hazardType,
                                            lat: alert.position.latitude,
                                            lng: alert.position.longitude,
                                            title: alert.title,
                                            locationName: alert.title,
                                          ),
                                        ),
                                      );
                                    },
                                    icon: const Icon(Icons.info_outline, size: 18),
                                    label: const Text("DETAILS"),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
