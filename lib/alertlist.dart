import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'Components/searchbar.dart';
import '/Components/menu.dart';
import 'alertdetails.dart';

class LocalAlert {
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final LatLng position;

  LocalAlert({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.position,
  });
}

class Alert extends StatelessWidget {
  const Alert({super.key});

  @override
  Widget build(BuildContext context) {
    // Mock data matching the coordinates used in home.dart
    final List<LocalAlert> mockAlerts = [
      LocalAlert(
        title: "Fire Alert",
        description: "Small brush fire reported near the stadium. Emergency services are on site.",
        icon: Icons.local_fire_department,
        color: Colors.red,
        position: const LatLng(44.567, -123.278),
      ),
      LocalAlert(
        title: "Police Presence",
        description: "Police investigating a minor incident downtown. Area remains open but use caution.",
        icon: Icons.security,
        color: Colors.blue,
        position: const LatLng(44.564, -123.261),
      ),
      LocalAlert(
        title: "Medical Emergency",
        description: "Ambulance on site near the medical center responding to a reported accident.",
        icon: Icons.add_box,
        color: Colors.green,
        position: const LatLng(44.588, -123.275),
      ),
      LocalAlert(
        title: "General Warning",
        description: "Caution: Slippery conditions in Avery Park due to recent weather.",
        icon: Icons.warning,
        color: Colors.amber,
        position: const LatLng(44.553, -123.270),
      ),
      LocalAlert(
        title: "Traffic Incident",
        description: "Road work causing delays on Highway 99. Expect 10-15 minute delays.",
        icon: Icons.directions_car,
        color: Colors.purple,
        position: const LatLng(44.560, -123.255),
      ),
    ];

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: const Menu(),
      body: Column(
        children: [
          const SearchBarApp(isOnAlertPage: true),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: mockAlerts.length,
              itemBuilder: (context, index) {
                final alert = mockAlerts[index];
                bool isSaved = false;

                return StatefulBuilder(
                  builder: (context, setState) {
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
                                  setState(() {
                                    isSaved = !isSaved;
                                  });
                                },
                              ),
                            ],
                          ),
                          const Divider(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              // "VIEW ON MAP" Button
                              TextButton.icon(
                                onPressed: () {
                                  Navigator.pushNamedAndRemoveUntil(
                                    context, 
                                    '/home', 
                                    (route) => false, 
                                    arguments: alert.position
                                  );
                                },
                                icon: const Icon(Icons.map, size: 18),
                                label: const Text("VIEW ON MAP"),
                              ),
                              // "DETAILS" Button
                              TextButton.icon(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => const AlertDetails(),
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
            ),
          ),
        ],
      ),
    );
  }
}
