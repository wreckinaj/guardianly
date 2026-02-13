import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '/Components/searchbar.dart';
import '/Components/menu.dart';
import '/Components/key.dart';

class AlertDetails extends StatefulWidget {
  const AlertDetails({super.key});

  @override
  State<AlertDetails> createState() => AlertDetailsState();
}

class AlertDetailsState extends State<AlertDetails> {
  bool showInfoBox = true;
  final MapController mapController = MapController();

  @override
  void dispose() {
    mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

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
                  // Actual FlutterMap
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: GestureDetector(
                      onTap: () {
                        if (showInfoBox) {
                          setState(() {
                            showInfoBox = false;
                          });
                        }
                      },
                      child: FlutterMap(
                        mapController: mapController,
                        options: const MapOptions(
                          initialCenter: LatLng(40.7128, -74.0060),
                          initialZoom: 12.0,
                        ),
                        children: [
                          TileLayer(
                            urlTemplate:
                                'https://api.mapbox.com/styles/v1/mapbox/streets-v12/tiles/{z}/{x}/{y}?access_token={accessToken}',
                            additionalOptions: {
                            'accessToken': dotenv.env['MAPBOX_TOKEN'] ?? '',
                          },
                          ),
                        ],
                      ),
                    ),
                  ),

                  // MapKey component
                  const Positioned(
                    bottom: 16,
                    left: 16,
                    child:  MapKey(),
                  
                  ),

                  // Enhanced INFO BOX
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    left: 0,
                    right: 0,
                    bottom: showInfoBox ? 0 : -screenHeight * 0.45,
                    height: screenHeight * 0.45,
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(24),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 12,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          // Draggable handle
                          Container(
                            width: 40,
                            height: 4,
                            margin: const EdgeInsets.only(top: 8, bottom: 8),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade400,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),

                          Expanded(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 8,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Header row
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          'Building Fire',
                                          style: TextStyle(
                                            fontSize: 22,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.red.shade800,
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.close, size: 22),
                                        onPressed: () {
                                          setState(() {
                                            showInfoBox = false;
                                          });
                                        },
                                        padding: EdgeInsets.zero,
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: 4),

                                  // Location
                                  Row(
                                    children: [
                                      Icon(Icons.location_on,
                                        size: 16,
                                        color: Colors.grey.shade600,
                                      ),
                                      const SizedBox(width: 6),
                                      const Text(
                                        'Amazon Warehouse - South Side',
                                        style: TextStyle(
                                          color: Colors.grey,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: 16),

                                  // Tags
                                  const Wrap(
                                    spacing: 12,
                                    runSpacing: 8,
                                    children: [
                                      Tag(label: 'Type: Fire', color: Colors.red),
                                      Tag(label: 'Severity: High', color: Colors.red),
                                    ],
                                  ),

                                  const SizedBox(height: 20),

                                  // Info grid
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade50,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.grey.shade200),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        buildInfoBlock(
                                          icon: Icons.directions_walk,
                                          title: 'Distance',
                                          value: '0.8 km',
                                        ),
                                        buildInfoBlock(
                                          icon: Icons.access_time,
                                          title: 'Reported',
                                          value: '15 min ago',
                                        ),
                                        buildInfoBlock(
                                          icon: Icons.local_fire_department,
                                          title: 'Status',
                                          value: 'Active',
                                        ),
                                      ],
                                    ),
                                  ),

                                  const SizedBox(height: 20),

                                  // Description
                                  const Text(
                                    'Description',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Fire department responding to building fire at south side of amazon warehouse. Multiple fire trucks and emergency personnel on scene.',
                                    style: TextStyle(
                                      height: 1.5,
                                      fontSize: 14,
                                    ),
                                  ),

                                  const SizedBox(height: 20),

                                  // Safety Instructions
                                  Container(
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: const Color(0x0DFF0000),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: const Color(0x33FF0000)
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(Icons.security,
                                              color: Colors.red.shade800,
                                              size: 20,
                                            ),
                                            const SizedBox(width: 8),
                                            const Text(
                                              'Safety Instructions',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                                color: Colors.red,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        const Text(
                                          'Evacuate the building immediately. Stay at least 500 meters away from the area. Follow instructions from emergency personnel.',
                                          style: TextStyle(
                                            height: 1.5,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                ],
                              ),
                            ),
                          ),
                        ],
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

  Widget buildInfoBlock({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Column(
      children: [
        Icon(icon, color: Colors.blue, size: 24),
        const SizedBox(height: 6),
        Text(
          title,
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}

// Tag widget
class Tag extends StatelessWidget {
  final String label;
  final Color color;

  const Tag({super.key, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(
        minWidth: 120,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 8,
      ),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withAlpha(26),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
      ),
    );
  }
}