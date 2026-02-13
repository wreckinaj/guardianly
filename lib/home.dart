import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '/Components/searchbar.dart';
import '/Components/menu.dart';
import '/Components/key.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => HomeState();
}

class HomeState extends State<Home> {
  final MapController mapController = MapController();
  bool showKeyBox = false;

  @override
  Widget build(BuildContext context) {
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
                  // Mapbox map
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
                  const Positioned(
                    bottom: 16,
                    left: 16,
                    child: MapKey(),
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
                  