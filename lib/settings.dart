import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '/Components/menu.dart';
import 'package:settings_ui/settings_ui.dart';
import 'policy.dart';

class Settings extends StatefulWidget {
  const Settings({super.key});

  @override
  State<Settings> createState() => _SettingsState();
}

class _SettingsState extends State<Settings> {
  bool locationShare = false;
  bool hazardAlerts = false;
  bool amberAlerts = false;
  bool weatherAlerts = false;
  bool mapBadges = false;
  
  late SharedPreferences _prefs;
  
  @override
  void initState() {
    super.initState();
    _loadSettings();
    _checkLocationPermissionStatus();
  }
  
  Future<void> _loadSettings() async {
    _prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        hazardAlerts = _prefs.getBool('hazardAlerts') ?? false;
        amberAlerts = _prefs.getBool('amberAlerts') ?? false;
        weatherAlerts = _prefs.getBool('weatherAlerts') ?? false;
        mapBadges = _prefs.getBool('mapBadges') ?? false;
      });
    }
  }
  
  Future<void> _saveSetting(String key, bool value) async {
    await _prefs.setBool(key, value);
  }

  Future<void> _checkLocationPermissionStatus() async {
    LocationPermission permission = await Geolocator.checkPermission();
    
    if (mounted) {
      setState(() {
        locationShare = (permission == LocationPermission.always ||
                       permission == LocationPermission.whileInUse);
      });
    }
  }

  Future<void> _handleLocationToggle(bool value) async {
    if (value) {
      LocationPermission permission = await Geolocator.checkPermission();
      
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        
        if (permission == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Location permission denied')),
            );
            setState(() => locationShare = false);
          }
          return;
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Location Permission Required'),
              content: const Text(
                'Location permission is permanently denied. Please enable it in device settings.'
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Geolocator.openAppSettings();
                  },
                  child: const Text('Open Settings'),
                ),
              ],
            ),
          );
          setState(() => locationShare = false);
        }
        return;
      }
      
      if (mounted) {
        setState(() => locationShare = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location sharing enabled')),
        );
      }
      
    } else {
      if (mounted) {
        final result = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Disable Location Sharing?'),
            content: const Text(
              'You will no longer receive proximity-based alerts. '
              'You can re-enable this in settings.'
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Open Settings'),
              ),
            ],
          ),
        );
        
        if (result == true && mounted) {
          await Geolocator.openAppSettings();
          setState(() => locationShare = false);
        } else {
          setState(() => locationShare = true);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: const Menu(),
      body: SettingsList(
        sections: [
          SettingsSection(
            title: const Text('Privacy'),
            tiles: <SettingsTile>[
              SettingsTile.switchTile(
                title: const Text('Share Location'),
                description: const Text('Allow app to access your location for nearby alerts'),
                initialValue: locationShare,
                onToggle: _handleLocationToggle,
              ),
            ],
          ),
          SettingsSection(
            title: const Text('Notifications'),
            tiles: <SettingsTile>[
              SettingsTile.switchTile(
                title: const Text('Allow Hazard Alerts'),
                description: const Text('Receive alerts for fires, police activity, and medical emergencies'),
                initialValue: hazardAlerts,
                onToggle: (value) {
                  setState(() => hazardAlerts = value);
                  _saveSetting('hazardAlerts', value);
                },
              ),
              SettingsTile.switchTile(
                title: const Text('Allow Amber Alerts'),
                description: const Text('Receive AMBER alerts for missing children'),
                initialValue: amberAlerts,
                onToggle: (value) {
                  setState(() => amberAlerts = value);
                  _saveSetting('amberAlerts', value);
                },
              ),
              SettingsTile.switchTile(
                title: const Text('Allow Weather Alerts'),
                description: const Text('Receive severe weather warnings'),
                initialValue: weatherAlerts,
                onToggle: (value) {
                  setState(() => weatherAlerts = value);
                  _saveSetting('weatherAlerts', value);
                }, 
              ),
            ], 
          ),
          SettingsSection(
            title: const Text('Map'),
            tiles: <SettingsTile>[
              SettingsTile.switchTile(
                title: const Text('Show Map Icon Badges'),
                description: const Text('Display alert badges on map markers'),
                initialValue: mapBadges,
                onToggle: (value) {
                  setState(() => mapBadges = value);
                  _saveSetting('mapBadges', value);
                },
              ),
            ],
          ),
          SettingsSection(
            tiles: <SettingsTile>[
              SettingsTile.navigation(
                title: const Text('Policies and Guidelines'),
                onPressed: (context) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const Policy()),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
