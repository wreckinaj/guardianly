import 'package:flutter/material.dart';
import '/Components/menu.dart';
import 'alertdetails.dart';

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
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: 3, // placeholder count
              itemBuilder: (context, index) {
                bool isSaved = false; // added
                
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
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Hazard indicator
                      Container(
                        width: 30,
                        height: 30,
                        margin: const EdgeInsets.only(
                          top: 20, 
                          right: 12
                        ),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                      ),

                      // Alert text
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Saved Alert $index',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Details about this saved alert will appear here.',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.black54,
                              ),
                            ),
                            const SizedBox(height: 6),
                            GestureDetector(
                              onTap: () {
                                if (index == 0) {
                                  // Navigate to AlertDetails for the first alert for now
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => const AlertDetails(),
                                    ),
                                  );
                                } 
                                else {
                                  // Placeholder for other alerts
                                }
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

                      // Saved icon - toggles
                      IconButton(
                        icon: Icon(
                          isSaved ? Icons.bookmark : Icons.bookmark_border,
                          color: isSaved ? Colors.black : Colors.grey,
                        ),
                        onPressed: () {
                          setState(() {
                            isSaved = !isSaved; // toggle save state
                        });
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
