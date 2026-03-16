import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import '../models/safety_recommendation.dart';
import 'package:flutter/foundation.dart';

class ApiService {
  // Use 10.0.2.2 for Android Emulator, localhost for iOS Simulator
  static const String baseUrl = 'https://guardianly-backend-34405523525.us-west1.run.app';

  // Helper to get the current user's token
  static Future<String?> _getAuthToken() async {
    User? user = FirebaseAuth.instance.currentUser;
    return await user?.getIdToken();
  }

  // Login function
  static Future<Map<String, dynamic>> login(String username, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'password': password,
        }),
      );

      if (response.statusCode == 200) {
        return {
          'success': true,
          'data': jsonDecode(response.body),
        };
      } else {
        final error = jsonDecode(response.body);
        return {
          'success': false,
          'error': error['error'] ?? 'Login failed',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Network error: $e',
      };
    }
  }

  // Register function
  static Future<Map<String, dynamic>> register(String username, String password, String email) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'password': password,
          'email': email,
        }),
      );

      if (response.statusCode == 201) {
        return {
          'success': true,
          'data': jsonDecode(response.body),
        };
      } else {
        final error = jsonDecode(response.body);
        return {
          'success': false,
          'error': error['error'] ?? 'Registration failed',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Network error: $e',
      };
    }
  }

  static Future<SafetyRecommendation?> generateSafetyAlert({
    required String hazardType,
    required double lat,
    required double lng,
  }) async {
    try {
      final token = await _getAuthToken();
      if (token == null) {
        throw Exception("User not authenticated");
      }

      final response = await http.post(
        Uri.parse('$baseUrl/api/generate_prompt'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'hazard': hazardType,
          'user_lat': lat,
          'user_lng': lng,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success' || data['status'] == 'warning') {
          return SafetyRecommendation.fromJson(data['recommendation']);
        }
      }
    } catch (e) {
      debugPrint('Network Error: $e');
    }
    return null;
  }

  // --- Report a New Alert ---
  static Future<bool> reportAlert({
    required String title,
    required String message,
    required String hazardType,
    required double lat,
    required double lng,
  }) async {
    final url = Uri.parse('$baseUrl/api/notifications');
    
    try {
      final token = await _getAuthToken();
      if (token == null) return false;

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'title': title,
          'message': message,
          'hazardType': hazardType,
          'lat': lat,
          'lng': lng,
        }),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        debugPrint('Success: Alert saved to database!');
        return true;
      } else {
        debugPrint('Failed to save alert: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('Network error while saving alert: $e');
      return false;
    }
  }
}
