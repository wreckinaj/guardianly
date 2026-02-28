import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '/Components/searchbar.dart';
import '/Components/menu.dart';
import '/Components/key.dart';
import '/services/api_service.dart';
import '/models/safety_recommendation.dart';

class AlertDetails extends StatefulWidget {
  final String hazardType;
  final double lat;
  final double lng;
  final String title;
  final String locationName;

  const AlertDetails({
    super.key,
    required this.hazardType,
    required this.lat,
    required this.lng,
    required this.title,
    required this.locationName,
  });

  @override
  State<AlertDetails> createState() => AlertDetailsState();
}

class AlertDetailsState extends State<AlertDetails> {
  bool showInfoBox = true;
  final MapController mapController = MapController();
  
  // --- AI State Variables ---
  SafetyRecommendation? _recommendation;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchAIRecommendation();
  }

  // --- Fetch RAG Data from Backend ---
  Future<void> _fetchAIRecommendation() async {
    setState(() => _isLoading = true);
    
    final result = await ApiService.generateSafetyAlert(
      hazardType: widget.hazardType,
      lat: widget.lat,
      lng: widget.lng,
    );

    if (mounted) {
      setState(() {
        _recommendation = result;
        _isLoading = false;
      });
    }
  }

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
                          setState(() => showInfoBox = false);
                        }
                      },
                      child: FlutterMap(
                        mapController: mapController,
                        options: MapOptions(
                          initialCenter: LatLng(widget.lat, widget.lng),
                          initialZoom: 14.0,
                        ),
                        children: [
                          TileLayer(
                            urlTemplate:
                                'https://api.mapbox.com/styles/v1/mapbox/streets-v12/tiles/{z}/{x}/{y}?access_token={accessToken}',
                            additionalOptions: const {
                              'accessToken':
                                  'pk.eyJ1Ijoic2hvb2tkIiwiYSI6ImNtaG9mNXE3ajBhbGYycXBzYmpsN2ppanEifQ.Zw3YIGnVLC9K36olfWBI6A',
                            },
                          ),
                          // Hazard Marker Layer
                          MarkerLayer(
                            markers: [
                              Marker(
                                point: LatLng(widget.lat, widget.lng),
                                width: 50.0,
                                height: 50.0,
                                child: const Icon(
                                  Icons.location_on,
                                  color: Colors.red,
                                  size: 40.0,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  // MapKey component
                  const Positioned(
                    bottom: 16,
                    left: 16,
                    child: MapKey(),
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
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          widget.title,
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
                                          setState(() => showInfoBox = false);
                                        },
                                        padding: EdgeInsets.zero,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),

                                  // Location
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.location_on,
                                        size: 16,
                                        color: Colors.grey.shade600,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        widget.locationName,
                                        style: const TextStyle(
                                          color: Colors.grey,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),

                                  // --- Conditional UI based on AI Loading State ---
                                  if (_isLoading)
                                    const Center(
                                      child: Padding(
                                        padding: EdgeInsets.all(32.0),
                                        child: CircularProgressIndicator(),
                                      ),
                                    )
                                  else if (_recommendation != null) ...[
                                    // Tags
                                    Wrap(
                                      spacing: 12,
                                      runSpacing: 8,
                                      children: [
                                        Tag(
                                            label: 'Type: ${widget.hazardType.split('_').join(' ').toUpperCase()}',
                                            color: Colors.red),
                                        Tag(
                                            label: 'Severity: ${_recommendation!.severity}',
                                            color: _recommendation!.severity == 'High' 
                                                ? Colors.red 
                                                : Colors.orange),
                                      ],
                                    ),
                                    const SizedBox(height: 20),

                                    // Description (Generated by AI)
                                    const Text(
                                      'AI Situation Analysis',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      _recommendation!.message,
                                      style: const TextStyle(
                                        height: 1.5,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 20),

                                    // Safety Instructions (Generated by AI)
                                    Container(
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                        color: const Color(0x0DFF0000),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                            color: const Color(0x33FF0000)),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.security,
                                                color: Colors.red.shade800,
                                                size: 20,
                                              ),
                                              const SizedBox(width: 8),
                                              const Text(
                                                'Recommended Actions',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                  color: Colors.red,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 12),
                                          // Map the AI actions to a list of bullet points
                                          ..._recommendation!.actions.map((action) => Padding(
                                            padding: const EdgeInsets.only(bottom: 8.0),
                                            child: Row(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                const Text("• ", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                                Expanded(child: Text(action, style: const TextStyle(height: 1.4))),
                                              ],
                                            ),
                                          )),
                                          const SizedBox(height: 8),
                                          Align(
                                            alignment: Alignment.centerRight,
                                            child: Text(
                                              'Source: ${_recommendation!.source}',
                                              style: TextStyle(fontSize: 10, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
                                            ),
                                          )
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 24),
                                  ] else
                                    // Error State
                                    const Text(
                                      'Failed to load safety recommendations. Please check your network connection.',
                                      style: TextStyle(color: Colors.red),
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
            ),
          ),
        ],
      ),
    );
  }
}

// Tag widget remains unchanged
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