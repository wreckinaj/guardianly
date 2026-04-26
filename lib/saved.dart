import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '/Components/menu.dart';
import 'alertdetails.dart';
//import '/models/local_alert.dart';
import 'saved_alerts_provider.dart';

class SavedAlerts extends StatelessWidget {
  const SavedAlerts({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: const Menu(),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Center(
              child: Text(
                "Saved Alerts",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          Expanded(
            child: Consumer<SavedAlertsProvider>(
              builder: (context, savedProvider, child) {
                if (savedProvider.savedAlerts.isEmpty) {
                  return const Center(
                    child: Text(
                      'No saved alerts yet',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: savedProvider.savedAlerts.length,
                  itemBuilder: (context, index) {
                    final alert = savedProvider.savedAlerts[index];
                    
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
                      child: Row(
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
                                const SizedBox(height: 6),
                                GestureDetector(
                                  onTap: () {
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
                                  },
                                  child: const Text(
                                    'Read more',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.blue,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.bookmark,
                              color: Colors.black,
                            ),
                            onPressed: () {
                              savedProvider.toggleSaveAlert(alert);
                            },
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