import 'package:flutter/material.dart';
// used Flutter code sample for [SearchBar] https://api.flutter.dev/flutter/material/SearchBar-class.html
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
  String selectedMiles = '5 miles';
  final SearchController controller = SearchController();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(10.0),
      child: Row(
        children: [
          Expanded(
            child: SearchAnchor(
              viewBackgroundColor: Colors.white,
              viewSurfaceTintColor: Colors.white,
              searchController: controller,
              builder: (BuildContext context, SearchController controller) {
                return SearchBar(
                  controller: controller,
                  hintText: "Search Map",
                  backgroundColor:
                      const WidgetStatePropertyAll<Color>(Colors.white),
                  shadowColor:
                      const WidgetStatePropertyAll<Color>(Colors.transparent),
                  padding: const WidgetStatePropertyAll<EdgeInsets>(
                    EdgeInsets.symmetric(horizontal: 15, vertical: 2),
                  ),
                  leading: const Icon(Icons.search),
                  shape: WidgetStatePropertyAll(
                    RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                      side: const BorderSide(
                        color: Colors.grey,
                        width: 1.0,
                      ),
                    ),
                  ),
                  trailing: [
                    DropdownButton<String>(
                      value: selectedMiles,
                      dropdownColor: Colors.white,
                      items: <String>['1 mile', '5 miles', '10 miles', '20 miles']
                          .map((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        setState(() {
                          selectedMiles = newValue!;
                        });
                      },
                    ),
                  ],
                  onTap: () {
                    controller.openView();
                  },
                  onChanged: (_) {
                    controller.openView();
                  },
                );
              },
              suggestionsBuilder: (BuildContext context, SearchController controller) {
                return [
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    title: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left side with name and address
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Costco',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '3130 Killdeer Ave SE, Albany, OR 97322',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        // Right side with distance and city
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '10 mi',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey.shade700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Albany, OR',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    onTap: () {
                      controller.closeView('Costco');
                      final currentContext = context; // Capture context
                      Future.delayed(const Duration(milliseconds: 100), () {
                        if (currentContext.mounted) { 
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const FromTo(),
                          ),
                        );
                        }
                      });
                    },
                  ),
                  const Divider(height: 1, thickness: 1, color: Colors.grey),
                  
                  ListTile(
                    title: const Text('item 1'),
                    onTap: () {
                      controller.closeView('item 1');
                    },
                  ),
                  const Divider(height: 1, thickness: 1, color: Colors.grey),
                  
                  ListTile(
                    title: const Text('item 2'),
                    onTap: () {
                      controller.closeView('item 2');
                    },
                  ),
                  const Divider(height: 1, thickness: 1, color: Colors.grey),
                  
                  ListTile(
                    title: const Text('item 3'),
                    onTap: () {
                      controller.closeView('item 3');
                    },
                  ),
                  const Divider(height: 1, thickness: 1, color: Colors.grey),
                  
                  ListTile(
                    title: const Text('item 4'),
                    onTap: () {
                      controller.closeView('item 4');
                    },
                  ),
                ];
              },
            ),
          ),
          const SizedBox(width: 20),
          ElevatedButton(
            onPressed: () {
              if (widget.isOnAlertPage) {
                // Go back to Home
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const Home(),
                  ),
                );
              } else {
                // Go to Alert List
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
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
            ),
            child: Text(
              widget.isOnAlertPage ? 'Back to Map' : 'Alert List',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }
}