import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'login.dart';
import 'signup.dart';
import 'home.dart';


Future<void> main() async {
  // Ensure widgets are bound before async calls
  WidgetsFlutterBinding.ensureInitialized();
  try {
    // Initialize Firebase
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    // NEW: confirm success in console
    debugPrint('Firebase.initializeApp() succeeded');
  } catch (e, st) {
    // Log init failure so platform channel errors are visible in console.
    // DO NOT rethrow here — allow app to start for debugging UI and native logs.
    print('Firebase.initializeApp() failed: $e');
    print(st);
    debugPrint('Continuing app start despite Firebase init failure (for debugging).');
    // Optionally set a boolean to show Firebase-disabled UI; omitted for brevity.
  }

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    // This runs after the first frame; when this prints, syncing is complete and UI is visible
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Use debugPrint so it's visible in flutter run output
      debugPrint('>>> SYNC COMPLETE: First frame rendered on device');
    });
  }

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: const Home(),


      routes:{
        '/signup': (context) => SignUpPage(),
        '/login': (context) => LoginPage(),
        '/home': (context) => const Home(),
      }
    );
  }
}
