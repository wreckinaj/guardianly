// lib/models/local_alert.dart
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
    return LocalAlert(
      position: LatLng(json['lat'] ?? 0.0, json['lng'] ?? 0.0),
      title: json['title'] ?? 'Alert',
      description: json['message'] ?? '',
      hazardType: json['hazardType'] ?? 'general', 
      icon: Icons.warning,
      color: Colors.red,
    );
  }
}