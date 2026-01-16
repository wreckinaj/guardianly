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

  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: const Menu(),
      body: SettingsList(
      sections: [
        SettingsSection(
          title: Text('Privacy'),
          tiles: <SettingsTile>[
            SettingsTile.switchTile(
              title: Text('Share Location'),
              initialValue: locationShare,
              onToggle: (value) {
                setState(() => locationShare = value);
              },
            ),
          ],
        ),

        SettingsSection(
          title: Text('Notifications'),
          tiles: <SettingsTile>[
            SettingsTile.switchTile(
              title: Text('Allow Hazard Alerts'),
              initialValue: hazardAlerts,
              onToggle: (value) {
                setState(() => hazardAlerts = value);
              },
            ),
            SettingsTile.switchTile(
              title: Text('Allow Amber Alerts'),
              initialValue: amberAlerts,
              onToggle: (value) {
                setState(() => amberAlerts = value);
              },
            ),
            SettingsTile.switchTile(
              title: Text('Allow Weather Alerts'),
              initialValue: weatherAlerts,
              onToggle: (value) {
                setState(() => weatherAlerts = value);
              }, 
            ),
          ], 
        ),

        SettingsSection(
          title: Text('Map'),
          tiles: <SettingsTile>[
            SettingsTile.switchTile(
              title: Text('Show Map Icon Badges'),
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