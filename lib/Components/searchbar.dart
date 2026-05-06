import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '/fromto.dart';
import '/alertlist.dart';
import '/home.dart';

class SearchBarApp extends StatefulWidget {
  final bool isOnAlertPage; 
  final Function(double?)? onRadiusChanged; // Callback for distance filtering
  
  const SearchBarApp({super.key, this.isOnAlertPage = false, this.onRadiusChanged});

  @override
  State<SearchBarApp> createState() => _SearchBarAppState();
}

class _SearchBarAppState extends State<SearchBarApp> {
  String? selectedMiles;
  final TextEditingController searchController = TextEditingController();
  
  List<Map<String, dynamic>> searchResults = [];
  bool isLoading = false;
  final String mapboxToken = 'pk.eyJ1Ijoic2hvb2tkIiwiYSI6ImNtaG9mNXE3ajBhbGYycXBzYmpsN2ppanEifQ.Zw3YIGnVLC9K36olfWBI6A';
  final FocusNode searchFocusNode = FocusNode();
  OverlayEntry? _overlayEntry;
  final GlobalKey _searchBarKey = GlobalKey();
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
    _overlayEntry = OverlayEntry(builder: (context) => _buildSuggestionsOverlay());
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
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 15,
                spreadRadius: 3,
              ),
            ],
          ),
          constraints: const BoxConstraints(maxHeight: 400),
          child: isLoading
              ? const Padding(padding: EdgeInsets.all(16.0), child: Center(child: SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))))
              : searchResults.isEmpty
                  ? const Padding(padding: EdgeInsets.all(16.0), child: Center(child: Text('No results found.')))
                  : ListView(shrinkWrap: true, physics: const ClampingScrollPhysics(), children: _buildSuggestionItems()),
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
      
      items.add(InkWell(
        onTap: () {
          setState(() => searchController.text = result['description']);
          _hideSuggestions();
          searchFocusNode.unfocus();
          Navigator.push(context, MaterialPageRoute(builder: (context) => FromTo(initialToAddress: result['description'])));
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(isAddress ? Icons.home : (isPOI ? Icons.restaurant : Icons.location_on), size: 18, color: isAddress ? Colors.green : (isPOI ? Colors.orange : Colors.blue)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(result['name'], style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(result['description'], style: TextStyle(fontSize: 12, color: Colors.grey.shade600), maxLines: 2, overflow: TextOverflow.ellipsis),
              ])),
            ],
          ),
        ),
      ));
      if (i < searchResults.length - 1) items.add(const Divider(height: 1, thickness: 1, color: Colors.grey));
    }
    return items;
  }

  Future<void> searchAddress(String query) async {
    if (query.isEmpty) { setState(() => searchResults = []); _hideSuggestions(); return; }
    if (_debounceTimer?.isActive ?? false) _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () async {
      setState(() => isLoading = true);
      try {
        final encodedSearchQuery = Uri.encodeComponent(query);
        String url = 'https://api.mapbox.com/geocoding/v5/mapbox.places/$encodedSearchQuery.json?access_token=$mapboxToken&limit=10&types=address,poi,place&country=US&proximity=-123.2620,44.5646&language=en&autocomplete=true';
        final response = await http.get(Uri.parse(url));
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final List<Map<String, dynamic>> suggestions = [];
          if (data['features'] != null) {
            for (var feature in data['features']) {
              suggestions.add({
                'description': feature['place_name'] ?? '',
                'name': feature['text'] ?? '',
                'coordinates': feature['center'],
                'type': feature['id']?.split('.')[0] ?? 'place',
              });
            }
          }
          setState(() { searchResults = suggestions; isLoading = false; });
          if (suggestions.isNotEmpty) _showSuggestions();
        }
      } catch (e) { debugPrint('Error: $e'); setState(() => isLoading = false); }
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
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.grey)),
              child: Row(
                children: [
                  const Padding(padding: EdgeInsets.only(left: 12), child: Icon(Icons.search, color: Colors.grey)),
                  Expanded(child: TextField(controller: searchController, focusNode: searchFocusNode, decoration: const InputDecoration(hintText: "Search proximity filter...", border: InputBorder.none, contentPadding: EdgeInsets.symmetric(vertical: 12, horizontal: 8)), onChanged: searchAddress)),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    child: DropdownButton<String>(
                      value: selectedMiles,
                      hint: const Text('Filter', style: TextStyle(fontSize: 12)),
                      dropdownColor: Colors.white,
                      underline: const SizedBox(),
                      icon: const Icon(Icons.filter_list, size: 18),
                      items: [
                        const DropdownMenuItem<String>(value: null, child: Text('No limit', style: TextStyle(fontSize: 12))),
                        ...<String>['1 mile', '5 miles', '10 miles', '25 miles', '50 miles']
                            .map((String value) => DropdownMenuItem<String>(value: value, child: Text(value, style: const TextStyle(fontSize: 12)))),
                      ],
                      onChanged: (String? newValue) {
                        setState(() => selectedMiles = newValue);
                        if (widget.onRadiusChanged != null) {
                          if (newValue == null) {
                            widget.onRadiusChanged!(null);
                          } else {
                            double radius = double.parse(newValue.split(' ')[0]);
                            widget.onRadiusChanged!(radius);
                          }
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => widget.isOnAlertPage ? const Home() : const Alert())),
            style: ElevatedButton.styleFrom(backgroundColor: const Color.fromARGB(255, 255, 234, 236), side: const BorderSide(color: Colors.red), foregroundColor: Colors.red, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15), minimumSize: const Size(80, 40)),
            child: Text(widget.isOnAlertPage ? 'Back' : 'Alert List', style: const TextStyle(fontWeight: FontWeight.bold, fontStyle: FontStyle.italic, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}
