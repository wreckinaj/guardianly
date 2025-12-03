import 'package:flutter/material.dart';
// used Flutter code sample for [SearchBar] https://api.flutter.dev/flutter/material/SearchBar-class.html

void main() => runApp(const SearchBarApp());

class SearchBarApp extends StatefulWidget {
  const SearchBarApp({super.key});

  @override
  State<SearchBarApp> createState() => _SearchBarAppState();
}

class _SearchBarAppState extends State<SearchBarApp> {
  String selectedMiles = '5 miles';

  @override
  Widget build(BuildContext context) {
    return Padding(
          padding: const EdgeInsets.all(10.0),
          child: Row(
            children: [
              Expanded(child:
         
          SearchAnchor(
            viewBackgroundColor: Colors.white,                    
            viewSurfaceTintColor: Colors.white,
            
            builder: (BuildContext context, SearchController controller) {
              
              return SearchBar(
                controller: controller,
                hintText: "Search Map",
                
                backgroundColor: const WidgetStatePropertyAll<Color>(Colors.white),
                shadowColor: const WidgetStatePropertyAll<Color>(Colors.transparent),

                padding: const WidgetStatePropertyAll<EdgeInsets>(
                  EdgeInsets.symmetric(horizontal: 15, vertical: 2),
                ),
                leading: const Icon(Icons.search),

                shape: WidgetStatePropertyAll(
                  RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15), // you can adjust
                    side: const BorderSide(
                      color: Colors.grey,
                      width: 1.0,   // <<< THICK GREY BORDER
                    ),
                  ),
                ),

                trailing:[
                  DropdownButton<String>(
                    value: selectedMiles,
                    dropdownColor: Colors.white,
                    items: <String>['1 mile', '5 miles','10 miles','20 miles']
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
              return List<ListTile>.generate(5, (int index) {
                final String item = 'item $index';
                return ListTile(
                  title: Text(item),
                  onTap: () {
                      controller.closeView(item);
                  },
                );
              });
            },
          ),
        ),

        const SizedBox(width: 20),

        ElevatedButton(
          onPressed: (){},
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color.fromARGB(255, 255, 234, 236),
            side: const BorderSide(color: Colors.red),
            foregroundColor: Colors.red,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
          ),
          child: const Text(
            'Alert List',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontStyle: FontStyle.italic,
              )),
        ),
            ],
          ),
    );

  }
}