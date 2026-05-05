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
  // Location settings
  bool locationShare = false;
  
  // Individual hazard toggles (matching local_alert.dart hazardType values)
  bool wildfireAlerts = false;
  bool policeActivityAlerts = false;
  bool medicalEmergencyAlerts = false;
  bool severeWeatherAlerts = false;
  bool roadClosureAlerts = false;
  
  // Map settings
  bool mapBadges = false;
  
  late SharedPreferences _prefs;
  
  @override
  void initState() {
    super.initState();
    _loadSettings();
    _updateLocationToggleState();
  }
  
  Future<void> _loadSettings() async {
    _prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        // Load all saved settings (default to true)
        locationShare = _prefs.getBool('locationShare') ?? true;
        wildfireAlerts = _prefs.getBool('wildfireAlerts') ?? true;
        policeActivityAlerts = _prefs.getBool('policeActivityAlerts') ?? true;
        medicalEmergencyAlerts = _prefs.getBool('medicalEmergencyAlerts') ?? true;
        severeWeatherAlerts = _prefs.getBool('severeWeatherAlerts') ?? true;
        roadClosureAlerts = _prefs.getBool('roadClosureAlerts') ?? true;
        mapBadges = _prefs.getBool('mapBadges') ?? true;
      });
    }
  }
  
  // Update the toggle state based on user preference AND device permission
  Future<void> _updateLocationToggleState() async {
    final prefs = await SharedPreferences.getInstance();
    final userPrefEnabled = prefs.getBool('locationShare') ?? true;
    
    LocationPermission permission = await Geolocator.checkPermission();
    final devicePermissionGranted = (permission == LocationPermission.always ||
                                     permission == LocationPermission.whileInUse);
    
    if (mounted) {
      setState(() {
        // Toggle is ON only if BOTH user preference AND device permission are true
        locationShare = userPrefEnabled && devicePermissionGranted;
      });
    }
  }
  
  Future<void> _saveSetting(String key, bool value) async {
    await _prefs.setBool(key, value);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_getSettingMessage(key, value)),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }
  
  String _getSettingMessage(String key, bool value) {
    final status = value ? 'enabled' : 'disabled';
    switch (key) {
      case 'locationShare': return 'Location sharing $status';
      case 'wildfireAlerts': return 'Fire alerts $status';
      case 'policeActivityAlerts': return 'Police activity alerts $status';
      case 'medicalEmergencyAlerts': return 'Medical emergency alerts $status';
      case 'severeWeatherAlerts': return 'Severe weather alerts $status';
      case 'roadClosureAlerts': return 'Road closure alerts $status';
      case 'mapBadges': return 'Map badges $status';
      default: return 'Setting updated';
    }
  }

  // Show disable location sharing dialog with logout-style formatting
  Future<bool> _showDisableLocationDialog() async {
    return await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: const Text(
            "Disable Location Sharing?",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
          content: const Text(
            "Are you sure you want to disable?",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.black54,
            ),
          ),
          actions: [
            const Divider(height: 1, thickness: 1),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () {
                        Navigator.of(context).pop(false);
                      },
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(color: Colors.grey.shade300),
                        ),
                      ),
                      child: const Text(
                        "Cancel",
                        style: TextStyle(
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextButton(
                      onPressed: () {
                        Navigator.of(context).pop(true);
                      },
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        "Disable",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    ).then((value) => value ?? false);
  }

  Future<void> _handleLocationToggle(bool value) async {
  if (value) {
    // User wants to ENABLE location sharing
    // Save preference first
    await _prefs.setBool('locationShare', true);
    
    LocationPermission permission = await Geolocator.checkPermission();
    
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      
      if (permission == LocationPermission.denied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permission denied')),
          );
          // Revert preference since permission denied
          await _prefs.setBool('locationShare', false);
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
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            title: const Text(
              "Location Permission Required",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
            content: const Text(
              "Location permission is permanently denied. Please enable it in device settings to receive location-based alerts.",
              textAlign: TextAlign.center,
            ),
            actions: [
              const Divider(height: 1, thickness: 1),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: BorderSide(color: Colors.grey.shade300),
                          ),
                        ),
                        child: const Text("Cancel"),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                          Geolocator.openAppSettings();
                        },
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text("Open Settings"),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
        // Revert preference
        await _prefs.setBool('locationShare', false);
        setState(() => locationShare = false);
      }
      return;
    }
    
    // Permission granted
    if (mounted) {
      setState(() => locationShare = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location sharing enabled - You will receive nearby alerts')),
      );
    }
    
  } else {
    // User wants to DISABLE location sharing
    final confirm = await _showDisableLocationDialog();

      if (confirm == true && mounted) {
        // Save preference as disabled
        await _prefs.setBool('locationShare', false);
        setState(() => locationShare = false);
        
        // Add a mounted check here as well
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location sharing disabled - Nearby alerts paused')),
          );
        }
      } else if (mounted) {
        // User cancelled, refresh the toggle state to show correct value
        await _updateLocationToggleState();
      }
  }
}
  
  // Method to get enabled hazard types matching local_alert.dart hazardType values
  List<String> getEnabledHazards() {
    List<String> enabled = [];
    if (wildfireAlerts) enabled.add('wildfire');
    if (policeActivityAlerts) enabled.add('police_activity');
    if (medicalEmergencyAlerts) enabled.add('medical_emergency');
    if (severeWeatherAlerts) enabled.add('severe_weather');
    if (roadClosureAlerts) enabled.add('road_closure');
    return enabled;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: const Menu(),
      body: SettingsList(
        sections: [
          SettingsSection(
            title: const Text('Privacy & Location'),
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
            title: const Text('Alert Types'),
            tiles: <SettingsTile>[
              SettingsTile.switchTile(
                title: const Text('Wildfire Alerts'),
                description: const Text('Wildfires, building fires, and fire hazards'),
                initialValue: wildfireAlerts,
                onToggle: (value) {
                  setState(() => wildfireAlerts = value);
                  _saveSetting('wildfireAlerts', value);
                },
              ),
              SettingsTile.switchTile(
                title: const Text('Police Activity'),
                description: const Text('Police presence, investigations, and incidents'),
                initialValue: policeActivityAlerts,
                onToggle: (value) {
                  setState(() => policeActivityAlerts = value);
                  _saveSetting('policeActivityAlerts', value);
                },
              ),
              SettingsTile.switchTile(
                title: const Text('Medical Emergency'),
                description: const Text('Ambulance responses, accidents, medical incidents'),
                initialValue: medicalEmergencyAlerts,
                onToggle: (value) {
                  setState(() => medicalEmergencyAlerts = value);
                  _saveSetting('medicalEmergencyAlerts', value);
                },
              ),
              SettingsTile.switchTile(
                title: const Text('Severe Weather'),
                description: const Text('Storms, floods, extreme temperature warnings'),
                initialValue: severeWeatherAlerts,
                onToggle: (value) {
                  setState(() => severeWeatherAlerts = value);
                  _saveSetting('severeWeatherAlerts', value);
                },
              ),
              SettingsTile.switchTile(
                title: const Text('Road Closure'),
                description: const Text('Road closures, accidents, and traffic hazards'),
                initialValue: roadClosureAlerts,
                onToggle: (value) {
                  setState(() => roadClosureAlerts = value);
                  _saveSetting('roadClosureAlerts', value);
                },
              ),
            ],
          ),
          SettingsSection(
            title: const Text('Map Display'),
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
            title: const Text('Legal'),
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
