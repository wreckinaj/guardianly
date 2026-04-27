import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

class LocalAlert {
  final LatLng position;
  final String title;
  final String description;
  final String hazardType; 
  final IconData icon;
  final Color color;

  LocalAlert({
    required this.position,
    required this.title,
    required this.description,
    required this.hazardType, 
    required this.icon,
    required this.color,
  });

  factory LocalAlert.fromJson(Map<String, dynamic> json) {
    // Correctly parse backend fields 'lat' and 'lng'
    double lat = (json['lat'] as num?)?.toDouble() ?? 0.0;
    double lng = (json['lng'] as num?)?.toDouble() ?? 0.0;
    
    String type = json['hazardType'] ?? 'general';
    
    // Map the string type to real Icons and Colors for the Map
    IconData icon;
    Color color;
    
    switch (type) {
      case 'wildfire':
        icon = Icons.local_fire_department;
        color = Colors.red;
        break;
      case 'police_activity':
        icon = Icons.security;
        color = Colors.blue;
        break;
      case 'medical_emergency':
        icon = Icons.add_box;
        color = Colors.green;
        break;
      case 'severe_weather':
        icon = Icons.warning;
        color = Colors.amber;
        break;
      case 'road_closure':
        icon = Icons.directions_car;
        color = Colors.purple;
        break;
      default:
        icon = Icons.warning_amber_rounded;
        color = Colors.orange;
    }

    return LocalAlert(
      position: LatLng(lat, lng),
      title: json['title'] ?? 'Alert',
      description: json['message'] ?? '', // Backend uses 'message'
      hazardType: type,
      icon: icon,
      color: color,
    );
  }
}
