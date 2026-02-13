import 'package:flutter/material.dart';
import 'Components/searchbar.dart';
import '/Components/menu.dart';
import 'alertdetails.dart';

class Alert extends StatelessWidget {
  const Alert({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: const Menu(),
      body: Column(
        children: [
          const SearchBarApp(isOnAlertPage: true),

          const SizedBox(height: 16),
          // Alert list with individual cards
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: 5, // example alerts
              itemBuilder: (context, index) {
                bool isSaved = false; // default state for save icon

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
                            margin: const EdgeInsets.only(top: 20, right: 12),
                            decoration: const BoxDecoration(
                              color: Colors.red, // can change based on severity
                              shape: BoxShape.circle,
                            ),
                          ),

                          // Alert text
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Alert $index', // title
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Details about the alert go here.', // details
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.black54,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                GestureDetector(
                                  onTap: () {
                                    // Placeholder for "Read More" action
                                    if (index == 0) {
                                      // Navigate to AlertDetails for the first alert for now
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => const AlertDetails(),
                                        ),
                                      );
                                    } else {
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

                          // Save/bookmark button
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
