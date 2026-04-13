import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '/fromto.dart';
import '/alertlist.dart';
import '/home.dart';

class SearchBarApp extends StatefulWidget {
  final bool isOnAlertPage; 
  
  const SearchBarApp({super.key, this.isOnAlertPage = false});

  @override
  State<SearchBarApp> createState() => _SearchBarAppState();
}

class _SearchBarAppState extends State<SearchBarApp> {
  String? selectedMiles;
  final TextEditingController searchController = TextEditingController();
  
  // For autocomplete suggestions
  List<Map<String, dynamic>> searchResults = [];
  bool isLoading = false;
  
  // Mapbox token
  final String mapboxToken = 'pk.eyJ1Ijoic2hvb2tkIiwiYSI6ImNtaG9mNXE3ajBhbGYycXBzYmpsN2ppanEifQ.Zw3YIGnVLC9K36olfWBI6A';
  
  // Focus node to manage keyboard
  final FocusNode searchFocusNode = FocusNode();
  
  // Overlay entry for suggestions
  OverlayEntry? _overlayEntry;
  
  // Global key to get the position of the search bar
  final GlobalKey _searchBarKey = GlobalKey();
  
  // Debounce timer to avoid too many API calls
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    
    searchFocusNode.addListener(() {
      if (!searchFocusNode.hasFocus) {
        _hideSuggestions();
      }
    });
  }

  @override
  void dispose() {
    searchController.dispose();
    searchFocusNode.dispose();
    _hideSuggestions();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _showSuggestions() {
    if (_overlayEntry != null) return;
    
    _overlayEntry = OverlayEntry(
      builder: (context) => _buildSuggestionsOverlay(),
    );
    
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _hideSuggestions() {
    _debounceTimer?.cancel();
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  Widget _buildSuggestionsOverlay() {
    final RenderBox renderBox = _searchBarKey.currentContext!.findRenderObject() as RenderBox;
    final position = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;
    
    return Positioned(
      top: position.dy + size.height + 5,
      left: position.dx,
      width: size.width,
      child: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3), // Fixed: using withValues instead of withOpacity
                blurRadius: 15,
                spreadRadius: 3,
              ),
            ],
          ),
          constraints: const BoxConstraints(maxHeight: 400),
          child: isLoading
              ? const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Center(
                    child: SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                )
              : searchResults.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Center(
                        child: Text('No results found. Try a different search.'),
                      ),
                    )
                  : ListView(
                      shrinkWrap: true,
                      physics: const ClampingScrollPhysics(),
                      children: _buildSuggestionItems(),
                    ),
        ),
      ),
    );
  }

  List<Widget> _buildSuggestionItems() {
    List<Widget> items = [];
    
    for (int i = 0; i < searchResults.length; i++) {
      final result = searchResults[i];
      final isAddress = result['type'] == 'address';
      final isPOI = result['type'] == 'poi' || result['type'] == 'restaurant' || result['type'] == 'cafe';
      
      items.add(
        InkWell(
          onTap: () {
            setState(() {
              searchController.text = result['description'];
            });
            _hideSuggestions();
            searchFocusNode.unfocus();
            
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => FromTo(
                  initialToAddress: result['description'],
                ),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  isAddress ? Icons.home : (isPOI ? Icons.restaurant : Icons.location_on),
                  size: 18,
                  color: isAddress ? Colors.green : (isPOI ? Colors.orange : Colors.blue),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        result['name'],
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        result['description'],
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (result['distance'] != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            result['distance']!,
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isAddress ? Colors.green.shade100 : (isPOI ? Colors.orange.shade100 : Colors.blue.shade100),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    isAddress ? 'Address' : (isPOI ? 'Place' : 'Location'),
                    style: TextStyle(
                      fontSize: 9,
                      color: isAddress ? Colors.green.shade700 : (isPOI ? Colors.orange.shade700 : Colors.blue.shade700),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      
      if (i < searchResults.length - 1) {
        items.add(const Divider(height: 1, thickness: 1, color: Colors.grey));
      }
    }
    
    return items;
  }

  Future<void> searchAddress(String query) async {
    if (query.isEmpty) {
      setState(() {
        searchResults = [];
      });
      _hideSuggestions();
      return;
    }

    // Debounce to avoid too many API calls while typing
    if (_debounceTimer?.isActive ?? false) _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () async {
      setState(() {
        isLoading = true;
      });

      try {
        // Removed unused encodedQuery variable
        String searchQuery = query;
        final encodedSearchQuery = Uri.encodeComponent(searchQuery);
        
        // Prioritize address results by putting 'address' first in types
        String url = 'https://api.mapbox.com/geocoding/v5/mapbox.places/$encodedSearchQuery.json'
            '?access_token=$mapboxToken'
            '&limit=10'
            '&types=address,poi,place,locality,neighborhood'
            '&country=US'
            '&proximity=-123.2620,44.5646'
            '&language=en'
            '&autocomplete=true';
        
        if (selectedMiles != null) {
          final miles = int.parse(selectedMiles!.split(' ')[0]);
          final limitMeters = (miles * 1609.34).toInt();
          url += '&limit=$limitMeters';
        }
        
        final response = await http.get(Uri.parse(url));
        
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final List<Map<String, dynamic>> suggestions = [];
          
          if (data['features'] != null && data['features'].isNotEmpty) {
            for (var feature in data['features']) {
              final placeName = feature['place_name'] ?? '';
              final featureType = feature['id']?.split('.')[0] ?? 'place';
              
              String name = feature['text'] ?? placeName.split(',').first;
              
              // For addresses, show the full street address
              if (featureType == 'address' && feature['address'] != null) {
                name = '${feature['address']} ${feature['text']}';
              }
              
              final parts = placeName.split(',');
              String cityState = '';
              if (parts.length >= 2) {
                cityState = parts[1].trim();
                if (parts.length >= 3) {
                  cityState = '${parts[1].trim()}, ${parts[2].trim()}';
                }
              }
              
              String? distance;
              if (feature['distance'] != null) {
                final meters = feature['distance'];
                final milesDist = (meters / 1609.34).toStringAsFixed(1);
                distance = '$milesDist mi away';
              }
              
              suggestions.add({
                'description': placeName,
                'name': name,
                'coordinates': feature['center'],
                'type': featureType,
                'cityState': cityState,
                'distance': distance,
              });
            }
          }
          
          // If still no results and query has numbers (likely an address), try adding city
          if (suggestions.isEmpty && RegExp(r'\d').hasMatch(query) && !query.contains('Corvallis')) {
            final cityQuery = '$query Corvallis';
            final encodedCityQuery = Uri.encodeComponent(cityQuery);
            final cityUrl = 'https://api.mapbox.com/geocoding/v5/mapbox.places/$encodedCityQuery.json'
                '?access_token=$mapboxToken'
                '&limit=5'
                '&types=address'
                '&country=US'
                '&proximity=-123.2620,44.5646'
                '&language=en';
            
            final cityResponse = await http.get(Uri.parse(cityUrl));
            if (cityResponse.statusCode == 200) {
              final cityData = json.decode(cityResponse.body);
              if (cityData['features'] != null && cityData['features'].isNotEmpty) {
                for (var feature in cityData['features']) {
                  final placeName = feature['place_name'] ?? '';
                  suggestions.add({
                    'description': placeName,
                    'name': feature['text'] ?? placeName.split(',').first,
                    'coordinates': feature['center'],
                    'type': 'address',
                    'cityState': '',
                    'distance': null,
                  });
                }
              }
            }
          }
          
          setState(() {
            searchResults = suggestions;
            isLoading = false;
          });
          
          if (suggestions.isNotEmpty) {
            _showSuggestions();
          } else {
            _hideSuggestions();
            setState(() {});
            _showSuggestions();
          }
        } else {
          setState(() {
            searchResults = [];
            isLoading = false;
          });
          _hideSuggestions();
        }
      } catch (e) {
        // Use debugPrint instead of print
        debugPrint('Error searching address: $e');
        setState(() {
          searchResults = [];
          isLoading = false;
        });
        _hideSuggestions();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(10.0),
      child: Row(
        children: [
          Expanded(
            child: Container(
              key: _searchBarKey,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.grey),
              ),
              child: Row(
                children: [
                  const Padding(
                    padding: EdgeInsets.only(left: 12),
                    child: Icon(Icons.search, color: Colors.grey),
                  ),
                  Expanded(
                    child: TextField(
                      controller: searchController,
                      focusNode: searchFocusNode,
                      decoration: const InputDecoration(
                        hintText: "Search addresses (try: 123 Main St, Corvallis) or places...",
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                      ),
                      onChanged: (value) {
                        searchAddress(value);
                      },
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    child: DropdownButton<String>(
                      value: selectedMiles,
                      hint: const Text('Miles', style: TextStyle(fontSize: 12)),
                      dropdownColor: Colors.white,
                      underline: const SizedBox(),
                      icon: const Icon(Icons.arrow_drop_down),
                      items: [
                        const DropdownMenuItem<String>(
                          value: null,
                          child: Text('No limit', style: TextStyle(fontSize: 12)),
                        ),
                        ...<String>['1 mile', '5 miles', '10 miles', '20 miles', '50 miles']
                            .map((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(value, style: const TextStyle(fontSize: 12)),
                          );
                        }),
                      ],
                      onChanged: (String? newValue) {
                        setState(() {
                          selectedMiles = newValue;
                        });
                        if (searchController.text.isNotEmpty) {
                          searchAddress(searchController.text);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: () {
              if (widget.isOnAlertPage) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const Home(),
                  ),
                );
              } else {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const Alert(),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color.fromARGB(255, 255, 234, 236),
              side: const BorderSide(color: Colors.red),
              foregroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
              minimumSize: const Size(80, 40),
            ),
            child: Text(
              widget.isOnAlertPage ? 'Back' : 'Alert List',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontStyle: FontStyle.italic,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
