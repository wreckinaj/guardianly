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
import 'package:geolocator/geolocator.dart';

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
  
  // For autocomplete suggestions
  List<Map<String, dynamic>> fromSuggestions = [];
  List<Map<String, dynamic>> toSuggestions = [];
  bool showFromSuggestions = false;
  bool showToSuggestions = false;
  
  // Focus nodes to manage keyboard
  final FocusNode fromFocusNode = FocusNode();
  final FocusNode toFocusNode = FocusNode();
  
  final String mapboxToken = 'pk.eyJ1Ijoic2hvb2tkIiwiYSI6ImNtaG9mNXE3ajBhbGYycXBzYmpsN2ppanEifQ.Zw3YIGnVLC9K36olfWBI6A';

  // Track which field is expanded
  String? _expandedField;
  
  // Limit suggestions to display
  static const int maxSuggestions = 5;

  // New variables for location feature
  bool _gettingLocation = false;

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
    
    // Add listeners to handle focus changes - only expand, never auto-close
    fromFocusNode.addListener(() {
      if (fromFocusNode.hasFocus && mounted) {
        setState(() {
          _expandedField = 'from';
          showFromSuggestions = true;
        });
      }
    });
    
    toFocusNode.addListener(() {
      if (toFocusNode.hasFocus && mounted) {
        setState(() {
          _expandedField = 'to';
          showToSuggestions = true;
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
  
  // Method to close expanded view and clear focus
  void _closeExpandedView() {
    // Remove focus from any text field
    fromFocusNode.unfocus();
    toFocusNode.unfocus();
    FocusScope.of(context).unfocus();
    
    setState(() {
      _expandedField = null;
      showFromSuggestions = false;
      showToSuggestions = false;
      fromSuggestions = [];
      toSuggestions = [];
    });
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
  }

  // Add reverse-geocoding method to convert coordinates to address
  Future<void> _reverseGeocodeAndSetFrom(double lat, double lng) async {
    try {
      final url = 'https://api.mapbox.com/geocoding/v5/mapbox.places/$lng,$lat.json'
          '?access_token=$mapboxToken'
          '&limit=1'
          '&types=address,poi,place,locality';

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['features'].isNotEmpty) {
          final address = data['features'][0]['place_name'];
          if (mounted) {
            setState(() {
              fromController.text = address;
            });
          }
        } else {
          // Fallback to coordinates if no address found
          if (mounted) {
            setState(() {
              fromController.text = '$lat, $lng';
            });
          }
        }
      }
    } catch (e) {
      debugPrint('Error reverse geocoding: $e');
      // Fallback to coordinates
      if (mounted) {
        setState(() {
          fromController.text = '$lat, $lng';
        });
      }
    }
  }

  Future<void> _setStartToMyLocation() async {
    setState(() => _gettingLocation = true);
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permission not granted.')),
        );
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      // Use reverse geocoding to get address instead of raw coordinates
      await _reverseGeocodeAndSetFrom(pos.latitude, pos.longitude);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to get location: $e')),
      );
    } finally {
      if (mounted) setState(() => _gettingLocation = false);
    }
  }


  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    // final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    
    final bool isExpanded = _expandedField != null;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const Menu(),
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          // Normal UI - visible when not expanded
          if (!isExpanded)
            Column(
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
                        const Positioned(
                          bottom: 16,
                          left: 16,
                          child: MapKey(),
                        ),
                        // INFO BOX
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: showInfoBox ? 0 : -screenHeight * 0.55,
                          child: Container(
                            height: screenHeight * 0.55,
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
                                                    color: Colors.grey,
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
                                                // Add "Use my location" button
                                                if (!_gettingLocation)
                                                  IconButton(
                                                    icon: const Icon(Icons.my_location, color: Colors.blue),
                                                    onPressed: _setStartToMyLocation,
                                                    tooltip: 'Use my location',
                                                  )
                                                else
                                                  const Padding(
                                                    padding: EdgeInsets.all(12),
                                                    child: SizedBox(
                                                      width: 20,
                                                      height: 20,
                                                      child: CircularProgressIndicator(strokeWidth: 2),
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
                                                    color: Colors.grey,
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
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  // GET DIRECTIONS BUTTON
                                  Center(
                                    child: ElevatedButton.icon(
                                      onPressed: () async {
                                        if (fromController.text.isEmpty || toController.text.isEmpty) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(
                                              content: Text('Please enter both locations'),
                                              backgroundColor: Colors.red,
                                            ),
                                          );
                                          return;
                                        }
                                        // Close expanded view if open
                                        _closeExpandedView();
                                        // Navigate to directions
                                        await Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => Directions(
                                              fromLocation: fromController.text,
                                              toLocation: toController.text,
                                              transportMode: 'drive',
                                            ),
                                          ),
                                        );
                                        // Ensure expanded view is closed when returning
                                        _closeExpandedView();
                                      },
                                      icon: const Icon(Icons.directions_car, size: 20),
                                      label: const Text(
                                        'GET DIRECTIONS',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green,
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 24,
                                          vertical: 14,
                                        ),
                                        elevation: 2,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
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
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

          // Expanded typing view - shows only the active text field and suggestions above keyboard
          if (isExpanded)
            Container(
              color: Colors.white,
              child: SafeArea(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // Suggestions list (limited to maxSuggestions, scrollable)
                    if ((_expandedField == 'from' && fromSuggestions.isNotEmpty) ||
                        (_expandedField == 'to' && toSuggestions.isNotEmpty))
                      Expanded(
                        child: ListView.builder(
                          shrinkWrap: true,
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          itemCount: _expandedField == 'from' 
                              ? (fromSuggestions.length > maxSuggestions ? maxSuggestions : fromSuggestions.length)
                              : (toSuggestions.length > maxSuggestions ? maxSuggestions : toSuggestions.length),
                          itemBuilder: (context, index) {
                            final suggestion = _expandedField == 'from' 
                                ? fromSuggestions[index] 
                                : toSuggestions[index];
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  const BoxShadow(
                                    color: Colors.black12,
                                    blurRadius: 4,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: ListTile(
                                leading: Icon(
                                  _expandedField == 'from' ? Icons.location_on : Icons.flag,
                                  color: Colors.grey,
                                ),
                                title: Text(
                                  suggestion['description'],
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                onTap: () {
                                  setState(() {
                                    if (_expandedField == 'from') {
                                      fromController.text = suggestion['description'];
                                      fromSuggestions = [];
                                      showFromSuggestions = false;
                                    } else {
                                      toController.text = suggestion['description'];
                                      toSuggestions = [];
                                      showToSuggestions = false;
                                    }
                                  });
                                  _closeExpandedView();
                                },
                              ),
                            );
                          },
                        ),
                      ),
                    
                    // Active text field right above keyboard
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          const BoxShadow(
                            color: Colors.black12,
                            blurRadius: 8,
                            offset: Offset(0, -2),
                          ),
                        ],
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _expandedField == 'from' ? Icons.location_on : Icons.flag,
                            color: Colors.blue,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _expandedField == 'from' ? fromController : toController,
                              focusNode: _expandedField == 'from' ? fromFocusNode : toFocusNode,
                              autofocus: true,
                              decoration: InputDecoration(
                                hintText: _expandedField == 'from' ? 'Enter starting address' : 'Enter destination address',
                                border: InputBorder.none,
                                hintStyle: const TextStyle(fontSize: 16),
                              ),
                              style: const TextStyle(fontSize: 18),
                              onChanged: (value) {
                                searchAddress(value, _expandedField == 'from');
                              },
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.grey),
                            onPressed: _closeExpandedView,
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
    );
  }
}
