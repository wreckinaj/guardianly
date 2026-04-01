import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // print('Testing Firebase initialization...');
  // print('Platform: ${DefaultFirebaseOptions.currentPlatform}');
  
  // Add a small delay to ensure everything is ready
  await Future.delayed(const Duration(seconds: 1));
  
  try {
    // Try with a named app first
    // print('🔥 Attempt 1: Initialize with default name...');
    await Firebase.initializeApp(
      name: 'test',
      options: DefaultFirebaseOptions.currentPlatform,
    );
    // print('✅ Firebase initialized successfully with named app!');
  } catch (e) {
    // print('❌ Attempt 1 failed: $e');
    
    // Try without name
    try {
      // print('🔥 Attempt 2: Initialize without name...');
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      // print('✅ Firebase initialized successfully!');
    } catch (e2) {
      // print('❌ Attempt 2 failed: $e2');
      // print('📚 Stack trace: $st2');
    }
  }
  
  runApp(MaterialApp(
    home: Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Firebase Test'),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                // print('🔄 Manual retry...');
                // Force a rebuild
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    ),
  ));
}
