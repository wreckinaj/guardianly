import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'firebase_options.dart';
import 'login.dart';
import 'signup.dart';
import 'home.dart';
import 'profile.dart';
import 'alertlist.dart';
import 'settings.dart';
import 'saved.dart';
import 'alertdetails.dart';
import 'forgot_pw.dart';
import 'reset_pw.dart';
import 'fromto.dart';



Future<void> main() async {
  // Ensure widgets are bound before async calls
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables
  await dotenv.load(fileName: ".env");

  try {
    // Initialize Firebase
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint('Firebase.initializeApp() succeeded');
  } catch (e, st) {
    debugPrint('Firebase.initializeApp() failed: $e');
    debugPrint(st.toString());
    debugPrint('Continuing app start despite Firebase init failure (for debugging).');
  }

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => MyAppState();
}

class MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      debugPrint('>>> SYNC COMPLETE: First frame rendered on device');
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: LoginPage(),
      routes:{
        '/signup': (context) => SignUpPage(),
        '/forgot_pw': (context) => const ForgotPW(),
        '/reset_pw': (context) => const ResetPW(),
        '/login': (context) => LoginPage(),
        '/home': (context) => const Home(),
        '/profile': (context) => const Profile(),
        '/alertlist': (context) => const Alert(),
        '/settings': (context) => const Settings(),
        '/saved': (context) => const SavedAlerts(),
        '/alertdetails': (context) => const AlertDetails(),
        '/fromto': (context) => const FromTo(),
      }
    );
  }
}
