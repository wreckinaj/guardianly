// lib/Components/key.dart
import 'package:flutter/material.dart';

class MapKey extends StatefulWidget {
  const MapKey({super.key});

  @override
  State<MapKey> createState() => MapKeyState();
}

class MapKeyState extends State<MapKey> {
  bool showKeyBox = false;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 100,
      height: 100,
      child: Stack(
        clipBehavior: Clip.none, // Allows widgets to overflow
        children: [
          // Key button
          Positioned(
            bottom: 0,
            left: 0,
            child: ElevatedButton(
              onPressed: () {
                setState(() {
                  showKeyBox = !showKeyBox;
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.red,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                elevation: 2,
              ),
              child: const Text(
                'Key',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),

          // Mini Key Box
          if (showKeyBox)
            Positioned(
              bottom: 50, // Position above the button
              left: 0,
              child: Container(
                width: 180,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ],
                  border: Border.all(
                    color: Colors.grey.shade300,
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Map Legend',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Colors.black,
                          ),
                        ),
                        Icon(
                          Icons.key,
                          size: 16,
                          color: Colors.red,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Divider(height: 1, color: Colors.grey),
                    const SizedBox(height: 8),
                    
                    // Key items
                    buildKeyItem(
                      icon: Icons.local_fire_department,
                      iconColor: Colors.red,
                      label: 'Fire Alert',
                      description: 'Active fire incidents',
                    ),
                    const SizedBox(height: 6),
                    buildKeyItem(
                      icon: Icons.local_police,
                      iconColor: Colors.blue,
                      label: 'Police',
                      description: 'Police presence',
                    ),
                    const SizedBox(height: 6),
                    buildKeyItem(
                      icon: Icons.local_hospital,
                      iconColor: Colors.green,
                      label: 'Medical',
                      description: 'Medical emergencies',
                    ),
                    const SizedBox(height: 6),
                    buildKeyItem(
                      icon: Icons.warning,
                      iconColor: Colors.orange,
                      label: 'Warning',
                      description: 'General warnings',
                    ),
                    const SizedBox(height: 6),
                    buildKeyItem(
                      icon: Icons.directions_car,
                      iconColor: Colors.purple,
                      label: 'Traffic',
                      description: 'Traffic incidents',
                    ),
                    const SizedBox(height: 6),
                    
                    // Close hint
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        'Tap Key to close',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey.shade600,
                          fontStyle: FontStyle.italic,
                        ),
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

  Widget buildKeyItem({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: iconColor.withValues(alpha: 0.3)),
          ),
          child: Icon(
            icon,
            size: 16,
            color: iconColor,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              Text(
                description,
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}