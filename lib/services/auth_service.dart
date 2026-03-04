import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Sign Up
  Future<UserCredential?> signUp(String email, String password) async {
    try {
      return await _auth.createUserWithEmailAndPassword(
        email: email, 
        password: password
      );
    } catch (e) {
      debugPrint("Signup Error: $e");
      return null;
    }
  }

  // Log In
  Future<UserCredential?> logIn(String email, String password) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email, 
        password: password
      );
    } catch (e) {
      debugPrint("Login Error: $e");
      return null;
    }
  }

  // Log Out
  Future<void> logOut() async {
    await _auth.signOut();
  }
  
  // Get the secure token to send to your Flask backend
  Future<String?> getToken() async {
    User? user = _auth.currentUser;
    return await user?.getIdToken();
  }
}