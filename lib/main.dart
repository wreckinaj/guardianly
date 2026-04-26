import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
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
import 'saved_alerts_provider.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AppInitializer());
}

class AppInitializer extends StatefulWidget {
  const AppInitializer({super.key});

  @override
  State<AppInitializer> createState() => _AppInitializerState();
}

class _AppInitializerState extends State<AppInitializer> {
  bool _isInitialized = false;
  bool _hasError = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      debugPrint('📱 Starting app initialization...');
      
      // Load environment variables
      await dotenv.load(fileName: ".env");
      debugPrint('✅ .env loaded');
      
      debugPrint('🔥 Initializing Firebase...');
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      debugPrint('✅ Firebase initialized successfully!');
      
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      debugPrint('❌ Initialization failed: $e');
      
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show loading while initializing
    if (!_isInitialized && !_hasError) {
      return const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Initializing app...'),
              ],
            ),
          ),
        ),
      );
    }

    // Show error if initialization failed
    if (_hasError) {
      return MaterialApp(
        home: Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 48),
                const SizedBox(height: 16),
                const Text(
                  'Failed to initialize app',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(_errorMessage),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _isInitialized = false;
                      _hasError = false;
                    });
                    _initializeApp();
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // App is initialized, show your main app
    return const MyApp();
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SavedAlertsProvider()),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        home: LoginPage(),
        routes: {
          '/signup': (context) => SignUpPage(),
          '/forgot_pw': (context) => const ForgotPW(),
          '/reset_pw': (context) => const ResetPW(),
          '/login': (context) => LoginPage(),
          '/home': (context) => const Home(),
          '/profile': (context) => const Profile(),
          '/alertlist': (context) => const Alert(),
          '/settings': (context) => const Settings(),
          '/saved': (context) => const SavedAlerts(),
          '/alertdetails': (context) => const AlertDetails(
            hazardType: 'building_fire',
            lat: 44.5646,
            lng: -123.2620,
            title: 'Building Fire',
            locationName: 'Amazon Warehouse - South Side',
          ),
          '/fromto': (context) => const FromTo(),
        },
      ),
    );
  }
}
