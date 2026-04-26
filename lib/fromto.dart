import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '/Components/searchbar.dart';
import '/Components/menu.dart';
import '/Components/key.dart';
import '/Components/textfield.dart';
import '/directions.dart';

class FromTo extends StatefulWidget {
  final String? initialFromAddress;
  final String? initialToAddress;
  
  const FromTo({
    super.key, 
    this.initialFromAddress,
    this.initialToAddress,
  });

  @override
  State<FromTo> createState() => FromToState();
}

class FromToState extends State<FromTo> {
  bool showInfoBox = true;
  TextEditingController fromController = TextEditingController();
  TextEditingController toController = TextEditingController();
  final MapController mapController = MapController();
  String selectedTransportMode = 'drive';
  
  // For autocomplete suggestions
  List<Map<String, dynamic>> fromSuggestions = [];
  List<Map<String, dynamic>> toSuggestions = [];
  bool showFromSuggestions = false;
  bool showToSuggestions = false;
  
  // Focus nodes to manage keyboard
  final FocusNode fromFocusNode = FocusNode();
  final FocusNode toFocusNode = FocusNode();
  
  final String mapboxToken = 'pk.eyJ1Ijoic2hvb2tkIiwiYSI6ImNtaG9mNXE3ajBhbGYycXBzYmpsN2ppanEifQ.Zw3YIGnVLC9K36olfWBI6A';

  @override
  void initState() {
    super.initState();
    
    // Set initial addresses if provided
    if (widget.initialFromAddress != null) {
      fromController.text = widget.initialFromAddress!;
    }
    if (widget.initialToAddress != null) {
      toController.text = widget.initialToAddress!;
    }
    
    // Add listeners to handle focus changes
    fromFocusNode.addListener(() {
      if (!fromFocusNode.hasFocus) {
        Future.delayed(const Duration(milliseconds: 200), () {
          if (mounted) {
            setState(() {
              showFromSuggestions = false;
            });
          }
        });
      }
    });
    
    toFocusNode.addListener(() {
      if (!toFocusNode.hasFocus) {
        Future.delayed(const Duration(milliseconds: 200), () {
          if (mounted) {
            setState(() {
              showToSuggestions = false;
            });
          }
        });
      }
    });
  }

  @override
  void dispose() {
    fromController.dispose();
    toController.dispose();
    mapController.dispose();
    fromFocusNode.dispose();
    toFocusNode.dispose();
    super.dispose();
  }

  Future<void> searchAddress(String query, bool isFrom) async {
    if (query.isEmpty) {
      setState(() {
        if (isFrom) {
          fromSuggestions = [];
          showFromSuggestions = false;
        } else {
          toSuggestions = [];
          showToSuggestions = false;
        }
      });
      return;
    }

    try {
      final encodedQuery = Uri.encodeComponent(query);
      final url = 'https://api.mapbox.com/geocoding/v5/mapbox.places/$encodedQuery.json'
          '?access_token=$mapboxToken'
          '&limit=5'
          '&types=address,poi,place,locality,neighborhood'
          '&country=US'
          '&language=en';
      
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<Map<String, dynamic>> suggestions = [];
        
        for (var feature in data['features']) {
          suggestions.add({
            'description': feature['place_name'],
            'coordinates': feature['center'],
          });
        }
        
        setState(() {
          if (isFrom) {
            fromSuggestions = suggestions;
            showFromSuggestions = suggestions.isNotEmpty;
          } else {
            toSuggestions = suggestions;
            showToSuggestions = suggestions.isNotEmpty;
          }
        });
      }
    } catch (e) {
      debugPrint('Error searching address: $e');
    }
  } // Removed the extra closing brace here

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const Menu(),
      resizeToAvoidBottomInset: true,
      body: GestureDetector(
        onTap: () {
          setState(() {
            showFromSuggestions = false;
            showToSuggestions = false;
          });
          FocusScope.of(context).unfocus();
        },
        child: Column(
          children: [
            const SearchBarApp(isOnAlertPage: false),
            const SizedBox(height: 16),

            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(
                  left: 24.0,
                  right: 24.0,
                  bottom: 32.0,
                ),
                child: Stack(
                  children: [
                    // Map
                    if (keyboardHeight == 0)
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
                              additionalOptions: const {
                                'accessToken':
                                    'pk.eyJ1Ijoic2hvb2tkIiwiYSI6ImNtaG9mNXE3ajBhbGYycXBzYmpsN2ppanEifQ.Zw3YIGnVLC9K36olfWBI6A',
                              },
                            ),
                          ],
                        ),
                      ),

                    // Map key
                    if (keyboardHeight == 0)
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
                      bottom: showInfoBox ? 0 : -screenHeight * 0.55,
                      height: keyboardHeight > 0 
                          ? screenHeight * 0.7
                          : screenHeight * 0.55,
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
                                reverse: true,
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
                                          // From input with autocomplete
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
                                              Container(
                                                decoration: BoxDecoration(
                                                  color: Colors.white,
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                child: Column(
                                                  children: [
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
                                                            hintText: 'Enter starting address',
                                                            obscureText: false,
                                                            focusNode: fromFocusNode,
                                                            onChanged: (value) {
                                                              searchAddress(value, true);
                                                            },
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    if (showFromSuggestions && fromSuggestions.isNotEmpty)
                                                      Container(
                                                        margin: const EdgeInsets.only(top: 4),
                                                        constraints: BoxConstraints(
                                                          maxHeight: keyboardHeight > 0 ? 150 : 200,
                                                        ),
                                                        decoration: BoxDecoration(
                                                          color: Colors.white,
                                                          borderRadius: BorderRadius.circular(8),
                                                          border: Border.all(color: Colors.grey.shade200),
                                                        ),
                                                        child: ListView.builder(
                                                          shrinkWrap: true,
                                                          physics: const ClampingScrollPhysics(),
                                                          itemCount: fromSuggestions.length,
                                                          itemBuilder: (context, index) {
                                                            final suggestion = fromSuggestions[index];
                                                            return InkWell(
                                                              onTap: () {
                                                                setState(() {
                                                                  fromController.text = suggestion['description'];
                                                                  showFromSuggestions = false;
                                                                  fromSuggestions = [];
                                                                });
                                                                fromFocusNode.unfocus();
                                                              },
                                                              child: Padding(
                                                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                                                child: Row(
                                                                  children: [
                                                                    const Icon(Icons.location_on, size: 16, color: Colors.grey),
                                                                    const SizedBox(width: 12),
                                                                    Expanded(
                                                                      child: Text(
                                                                        suggestion['description'],
                                                                        style: const TextStyle(fontSize: 14),
                                                                        maxLines: 2,
                                                                        overflow: TextOverflow.ellipsis,
                                                                      ),
                                                                    ),
                                                                  ],
                                                                ),
                                                              ),
                                                            );
                                                          },
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 12),
                                          
                                          // To input with autocomplete
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
                                              Container(
                                                decoration: BoxDecoration(
                                                  color: Colors.white,
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                child: Column(
                                                  children: [
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
                                                            hintText: 'Enter destination address',
                                                            obscureText: false,
                                                            focusNode: toFocusNode,
                                                            onChanged: (value) {
                                                              searchAddress(value, false);
                                                            },
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    if (showToSuggestions && toSuggestions.isNotEmpty)
                                                      Container(
                                                        margin: const EdgeInsets.only(top: 4),
                                                        constraints: BoxConstraints(
                                                          maxHeight: keyboardHeight > 0 ? 150 : 200,
                                                        ),
                                                        decoration: BoxDecoration(
                                                          color: Colors.white,
                                                          borderRadius: BorderRadius.circular(8),
                                                          border: Border.all(color: Colors.grey.shade200),
                                                        ),
                                                        child: ListView.builder(
                                                          shrinkWrap: true,
                                                          physics: const ClampingScrollPhysics(),
                                                          itemCount: toSuggestions.length,
                                                          itemBuilder: (context, index) {
                                                            final suggestion = toSuggestions[index];
                                                            return InkWell(
                                                              onTap: () {
                                                                setState(() {
                                                                  toController.text = suggestion['description'];
                                                                  showToSuggestions = false;
                                                                  toSuggestions = [];
                                                                });
                                                                toFocusNode.unfocus();
                                                              },
                                                              child: Padding(
                                                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                                                child: Row(
                                                                  children: [
                                                                    const Icon(Icons.flag, size: 16, color: Colors.grey),
                                                                    const SizedBox(width: 12),
                                                                    Expanded(
                                                                      child: Text(
                                                                        suggestion['description'],
                                                                        style: const TextStyle(fontSize: 14),
                                                                        maxLines: 2,
                                                                        overflow: TextOverflow.ellipsis,
                                                                      ),
                                                                    ),
                                                                  ],
                                                                ),
                                                              ),
                                                            );
                                                          },
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),

                                    const SizedBox(height: 16),

                                    if (keyboardHeight == 0) ...[
                                      const Text(
                                        'Select Transport Mode',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      
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
                                    ],

                                    Center(
                                      child: ElevatedButton(
                                        onPressed: () {
                                          if (fromController.text.isEmpty || toController.text.isEmpty) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(
                                                content: Text('Please enter both locations'),
                                                backgroundColor: Colors.red,
                                              ),
                                            );
                                            return;
                                          }
                                          
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
                                    
                                    if (keyboardHeight == 0)
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: Colors.blue.shade50,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Row(
                                          children: [
                                            Icon(Icons.info_outline, size: 16, color: Colors.blue),
                                            SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                'Try typing: "Oregon State University", "18550 SW Kinnaman Rd", or "1600 Pennsylvania Ave"',
                                                style: TextStyle(fontSize: 12, color: Colors.blue),
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
