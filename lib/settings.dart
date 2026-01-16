import 'package:flutter/material.dart';
import '/Components/menu.dart';
import 'package:settings_ui/settings_ui.dart';


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
              initialValue: locationShare,
              onToggle: (value) {
                setState(() => locationShare = value);
              },
            ),
          ],
        ),

        SettingsSection(
          title: const Text('Notifications'),
          tiles: <SettingsTile>[
            SettingsTile.switchTile(
              title: const Text('Allow Hazard Alerts'),
              initialValue: hazardAlerts,
              onToggle: (value) {
                setState(() => hazardAlerts = value);
              },
            ),
            SettingsTile.switchTile(
              title: const Text('Allow Amber Alerts'),
              initialValue: amberAlerts,
              onToggle: (value) {
                setState(() => amberAlerts = value);
              },
            ),
            SettingsTile.switchTile(
              title: const Text('Allow Weather Alerts'),
              initialValue: weatherAlerts,
              onToggle: (value) {
                setState(() => weatherAlerts = value);
              }, 
            ),
          ], 
        ),

        SettingsSection(
          title: const Text('Map'),
          tiles: <SettingsTile>[
            SettingsTile.switchTile(
              title: const Text('Show Map Icon Badges'),
              initialValue: mapBadges,
              onToggle: (value) {
                setState(() => mapBadges = value);
              },
            ),
          ],
        ),
      ],
    ),
  );
  }
}