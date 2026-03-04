import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class NotificationService {
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> initialize() async {
    // 1. Request permission (Required for iOS and Android 13+)
    NotificationSettings settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint('User granted push notification permission');
      
      // 2. Fetch the unique FCM device token
      String? token = await _fcm.getToken();
      if (token != null) {
        debugPrint('FCM Token generated: $token');
        await _saveTokenToDatabase(token);
      }

      // 3. Listen for token refreshes (Firebase occasionally rotates these)
      _fcm.onTokenRefresh.listen(_saveTokenToDatabase);
      
    } else {
      debugPrint('User declined push notification permissions');
    }
  }

  // --- Helper method to securely update the user's document ---
  Future<void> _saveTokenToDatabase(String token) async {
    String? userId = _auth.currentUser?.uid;
    
    if (userId != null) {
      await _db.collection('users').doc(userId).set({
        'fcm_token': token,
        'fcm_token_updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)); // merge: true ensures we don't overwrite their username/email!
    }
  }
}