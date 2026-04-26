import 'package:flutter/material.dart';
import 'models/local_alert.dart';

class SavedAlertsProvider extends ChangeNotifier {
  final List<LocalAlert> _savedAlerts = [];

  List<LocalAlert> get savedAlerts => _savedAlerts;

  void toggleSaveAlert(LocalAlert alert) {
    if (_isAlertSaved(alert)) {
      _savedAlerts.removeWhere((saved) => 
        saved.title == alert.title && 
        saved.position.latitude == alert.position.latitude &&
        saved.position.longitude == alert.position.longitude
      );
    } else {
      _savedAlerts.add(alert);
    }
    notifyListeners();
  }

  bool isAlertSaved(LocalAlert alert) {
    return _savedAlerts.any((saved) => 
      saved.title == alert.title && 
      saved.position.latitude == alert.position.latitude &&
      saved.position.longitude == alert.position.longitude
    );
  }

  bool _isAlertSaved(LocalAlert alert) {
    return _savedAlerts.any((saved) => 
      saved.title == alert.title && 
      saved.position.latitude == alert.position.latitude &&
      saved.position.longitude == alert.position.longitude
    );
  }
}
