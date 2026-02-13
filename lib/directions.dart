import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '/Components/key.dart';

class Directions extends StatefulWidget {
  final String fromLocation;
  final String toLocation;
  final String transportMode;

  const Directions({
    super.key,
    required this.fromLocation,
    required this.toLocation,
    required this.transportMode,
  });

  @override
  State<Directions> createState() => DirectionsState();
}

class DirectionsState extends State<Directions> {
  bool showDirections = true;
  bool isPanelExpanded = true;
  TextEditingController fromController = TextEditingController();
  TextEditingController toController = TextEditingController();
  final MapController mapController = MapController();
  
  List<DirectionStep> directions = [];
  RouteSummary? routeSummary;
  bool isLoadingDirections = false;

  @override
  void initState() {
    super.initState();
    // Set the controllers with the passed values
    fromController.text = widget.fromLocation;
    toController.text = widget.toLocation;
    
    // Load mock data
    loadMockData();
  }

  void loadMockData() {
    setState(() {
      directions = [
        DirectionStep(
          instruction: 'NW 19th St toward NW Tyler Ave',
          distance: '0.2 mi',
          duration: '3 min',
          arrivalTime: '9:33',
          turnIcon: Icons.straight,
          turnColor: Colors.blue,
          stepNumber: 1,
          isCurrent: true,
        ),
        DirectionStep(
          instruction: 'Turn left onto NW Tyler Ave',
          distance: '0.5 mi',
          duration: '2 min',
          arrivalTime: '9:35',
          turnIcon: Icons.turn_left,
          turnColor: Colors.orange,
          stepNumber: 2,
          isCurrent: false,
        ),
        DirectionStep(
          instruction: 'Turn right onto Main St',
          distance: '1.2 mi',
          duration: '5 min',
          arrivalTime: '9:40',
          turnIcon: Icons.turn_right,
          turnColor: Colors.green,
          stepNumber: 3,
          isCurrent: false,
        ),
        DirectionStep(
          instruction: 'Arrive at destination',
          distance: '',
          duration: '',
          arrivalTime: '',
          turnIcon: Icons.location_on,
          turnColor: Colors.red,
          stepNumber: 4,
          isCurrent: false,
        ),
      ];
      
      routeSummary = RouteSummary(
        totalDistance: '1.9 mi',
        totalDuration: '10 min',
        arrivalTime: '9:40 AM',
        startAddress: widget.fromLocation,
        endAddress: widget.toLocation,
      );
    });
  }

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
    
    // Get transport mode icon and label
    final transportIcon = getTransportIcon(widget.transportMode);
    final transportLabel = getTransportLabel(widget.transportMode);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Directions ($transportLabel)',
          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24.0, 16.0, 24.0, 32.0),
              child: Stack(
                children: [
                  // Map
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    
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
                          /*additionalOptions: const {
                            'accessToken':
                                'pk.eyJ1Ijoic2hvb2tkIiwiYSI6ImNtaG9mNXE3ajBhbGYycXBzYmpsN2ppanEifQ.Zw3YIGnVLC9K36olfWBI6A',
                          },*/
                          additionalOptions: {
                            'accessToken': dotenv.env['MAPBOX_TOKEN'] ?? '',
                          },
                        ),
                      ],
                    ),
                  ),

                  // Map Key button
                  const Positioned(
                    bottom: 16,
                    left: 16,
                    child: MapKey(),
                  ),

                  // Directions Panel
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: buildDirectionsPanel(screenHeight, transportIcon, transportLabel),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildDirectionsPanel(double screenHeight, IconData transportIcon, String transportLabel) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      height: isPanelExpanded ? screenHeight * 0.45 : screenHeight * 0.08,
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
          // Handle indicator with tap gesture
          GestureDetector(
            onTap: () {
              setState(() {
                isPanelExpanded = !isPanelExpanded;
              });
            },
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              decoration: BoxDecoration(
                color: Colors.grey.shade400,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Show content only when expanded
          if (isPanelExpanded) ...[
        

            // Scrollable content area
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Route Summary section
                    if (routeSummary != null) ...[
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            
                            // Route summary
                            const Text(
                              'Route Details',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),

                            const SizedBox(height: 15),


                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                // Total Distance
                                Column(
                                  children: [
                                    const Icon(
                                      Icons.directions,
                                      color: Colors.blue,
                                      size: 24,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Distance',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      routeSummary!.totalDistance,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                
                                // Total Time
                                Column(
                                  children: [
                                    const Icon(
                                      Icons.access_time,
                                      color: Colors.blue,
                                      size: 24,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Time',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      routeSummary!.totalDuration,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                
                                // Arrival Time
                                Column(
                                  children: [
                                    const Icon(
                                      Icons.schedule,
                                      color: Colors.blue,
                                      size: 24,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Arrival',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      routeSummary!.arrivalTime,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            
                            const Divider(), 
                            const SizedBox(height: 15),
                            
                            buildSummaryItem(Icons.location_on, 'From:', routeSummary!.startAddress),
                            const SizedBox(height: 10),
                            buildSummaryItem(Icons.flag, 'To:', routeSummary!.endAddress),
                            
                            const SizedBox(height: 15),
                            const Divider(),
                            
                            // Turn-by-turn directions header
                            const Text(
                              'Turn-by-Turn Directions',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 10),
                          ],
                        ),
                      ),
                    ],

                    // Directions steps list
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        children: [
                          for (int i = 0; i < directions.length; i++)
                            buildDirectionStep(directions[i]),
                          const SizedBox(height: 20), // Add some bottom padding
                        ],
                      ),
                    ),

                    // Bottom action buttons
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        border: Border(
                          top: BorderSide(color: Colors.grey.shade200),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Exit button
                          OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 32,
                                vertical: 12,
                              ),
                            ),
                            child: const Text(
                              'Exit',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),

                          // Start Navigation button
                          ElevatedButton(
                            onPressed: () {
                              // Start turn-by-turn navigation
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 32,
                                vertical: 12,
                              ),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.navigation, size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'Start Navigation',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget buildSummaryItem(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          color: Colors.blue,
          size: 20,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget buildDirectionStep(DirectionStep step) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: step.isCurrent ? step.turnColor.withValues(alpha: 0.2) : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: step.isCurrent ? step.turnColor : Colors.grey.shade300,
                    width: step.isCurrent ? 2 : 1,
                  ),
                ),
                child: Center(
                  child: Text(
                    step.stepNumber.toString(),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: step.isCurrent ? step.turnColor : Colors.grey.shade700,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Icon(
                step.turnIcon,
                color: step.turnColor,
                size: 20,
              ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  step.instruction,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: step.isCurrent ? FontWeight.w600 : FontWeight.normal,
                    color: step.isCurrent ? Colors.black : Colors.black87,
                  ),
                ),
                if (step.distance.isNotEmpty && step.duration.isNotEmpty)
                  const SizedBox(height: 4),
                if (step.distance.isNotEmpty && step.duration.isNotEmpty)
                  Row(
                    children: [
                      Text(
                        step.distance,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 4,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade400,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        step.duration,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData getTransportIcon(String mode) {
    switch (mode) {
      case 'walk':
        return Icons.directions_walk;
      case 'drive':
        return Icons.directions_car;
      case 'transit':
        return Icons.directions_bus;
      case 'bike':
        return Icons.directions_bike;
      default:
        return Icons.directions_car;
    }
  }

  String getTransportLabel(String mode) {
    switch (mode) {
      case 'walk':
        return 'Walking';
      case 'drive':
        return 'Driving';
      case 'transit':
        return 'Public Transit';
      case 'bike':
        return 'Biking';
      default:
        return 'Driving';
    }
  }
}

class DirectionStep {
  final String instruction;
  final String distance;
  final String duration;
  final String arrivalTime;
  final IconData turnIcon;
  final Color turnColor;
  final int stepNumber;
  final bool isCurrent;

  DirectionStep({
    required this.instruction,
    required this.distance,
    required this.duration,
    required this.arrivalTime,
    required this.turnIcon,
    required this.turnColor,
    required this.stepNumber,
    required this.isCurrent,
  });
}

class RouteSummary {
  final String totalDistance;
  final String totalDuration;
  final String arrivalTime;
  final String startAddress;
  final String endAddress;

  RouteSummary({
    required this.totalDistance,
    required this.totalDuration,
    required this.arrivalTime,
    required this.startAddress,
    required this.endAddress,
  });
}