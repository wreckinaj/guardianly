import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '/Components/searchbar.dart';
import '/Components/menu.dart';
import '/Components/key.dart';
import '/Components/textfield.dart';
import '/directions.dart';

class FromTo extends StatefulWidget {
  const FromTo({super.key});

  @override
  State<FromTo> createState() => FromToState();
}

class FromToState extends State<FromTo> {
  bool showInfoBox = true;
  TextEditingController fromController = TextEditingController();
  TextEditingController toController = TextEditingController();
  final MapController mapController = MapController();
  String selectedTransportMode = 'drive';

  @override
  void dispose() {
    fromController.dispose();
    toController.dispose();
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
                  // Map
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

                  // Map key
                  const Positioned(
                    bottom: 16,
                    left: 16,
                    child: MapKey(),
                  ),

                  // INFO BOX
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
                          Expanded(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 16,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Header row
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Expanded(
                                        child: Text(
                                          'Directions',
                                          style: TextStyle(
                                            fontSize: 22,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black,
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

                                  const SizedBox(height: 5),

                                  // From/To Input Container
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade50,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.grey.shade200),
                                    ),
                                    child: Column(
                                      children: [
                                        // From input
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'From',
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.grey.shade700,
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            Row(
                                              children: [
                                                const Padding(
                                                  padding: EdgeInsets.only(left: 12, right: 8),
                                                  child: Icon(
                                                    Icons.location_on,
                                                    color: Colors.blue,
                                                    size: 20,
                                                  ),
                                                ),
                                                Expanded(
                                                  child: MyTextField(
                                                    controller: fromController,
                                                    hintText: 'Enter starting location',
                                                    obscureText: false,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        
                                        // To input
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'To',
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.grey.shade700,
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            Row(
                                              children: [
                                                const Padding(
                                                  padding: EdgeInsets.only(left: 12, right: 8),
                                                  child: Icon(
                                                    Icons.flag,
                                                    color: Colors.blue,
                                                    size: 20,
                                                  ),
                                                ),
                                                Expanded(
                                                  child: MyTextField(
                                                    controller: toController,
                                                    hintText: 'Enter destination',
                                                    obscureText: false,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),

                                  const SizedBox(height: 16),

                                  // Transport mode selection
                                  const Text(
                                    'Select Transport Mode',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  
                                  // Transport mode options
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      buildTransportOption(
                                        icon: Icons.directions_walk,
                                        label: 'Walk',
                                        mode: 'walk',
                                      ),
                                      buildTransportOption(
                                        icon: Icons.directions_car,
                                        label: 'Drive',
                                        mode: 'drive',
                                      ),
                                      buildTransportOption(
                                        icon: Icons.directions_bus,
                                        label: 'Transit',
                                        mode: 'transit',
                                      ),
                                      buildTransportOption(
                                        icon: Icons.directions_bike,
                                        label: 'Bike',
                                        mode: 'bike',
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: 24),

                                  // START button at the bottom
                                  Center(
                                    child: ElevatedButton(
                                      onPressed: () {
                                        // Validate inputs
                                        if (fromController.text.isEmpty || toController.text.isEmpty) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(
                                              content: Text('Please enter both locations'),
                                              backgroundColor: Colors.red,
                                            ),
                                          );
                                          return;
                                        }
                                        
                                        // Navigate to directions screen
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => Directions(
                                              fromLocation: fromController.text,
                                              toLocation: toController.text,
                                              transportMode: selectedTransportMode,
                                            ),
                                          ),
                                        );
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green,
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 100,
                                          vertical: 16,
                                        ),
                                        elevation: 4,
                                      ),
                                      child: const Text(
                                        'GET DIRECTIONS',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
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

  Widget buildTransportOption({
    required IconData icon,
    required String label,
    required String mode,
  }) {
    bool isSelected = selectedTransportMode == mode;
    return GestureDetector(
      onTap: () {
        setState(() {
          selectedTransportMode = mode;
        });
      },
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: isSelected ? Colors.blue.shade50 : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: isSelected ? Colors.blue : Colors.grey.shade300,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Icon(
              icon,
              color: isSelected ? Colors.blue : Colors.grey.shade700,
              size: 28,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              color: isSelected ? Colors.blue : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}