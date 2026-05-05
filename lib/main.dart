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
import 'package:shared_preferences/shared_preferences.dart';

// --- RadiusProvider to keep selected radius across page refreshes/navigation ---
class RadiusProvider extends ChangeNotifier {
  static const _prefsKey = 'filter_radius_miles';

  double? _radiusMiles; // null means "No limit"
  bool _isLoaded = false;

  double? get radiusMiles => _radiusMiles;
  bool get isLoaded => _isLoaded;

  Future<void> load() async {
    if (_isLoaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.containsKey(_prefsKey)) {
        _radiusMiles = prefs.getDouble(_prefsKey);
      } else {
        _radiusMiles = null; // Default to no limit
      }
    } catch (e) {
      debugPrint('RadiusProvider.load() failed: $e');
    } finally {
      _isLoaded = true;
      notifyListeners();
    }
  }

  Future<void> setRadiusMiles(double? miles) async {
    if (miles == _radiusMiles) return;
    _radiusMiles = miles;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      if (miles == null) {
        await prefs.remove(_prefsKey);
      } else {
        await prefs.setDouble(_prefsKey, miles);
      }
    } catch (e) {
      debugPrint('RadiusProvider.setRadiusMiles() failed to persist: $e');
    }
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final radiusProvider = RadiusProvider();
  await radiusProvider.load();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SavedAlertsProvider()),
        ChangeNotifierProvider.value(value: radiusProvider),
      ],
      child: const AppInitializer(),
    ),
  );
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
      await dotenv.load(fileName: ".env");
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
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

    return const MyApp();
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: const Home(), // FIXED: Added const
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
    );
  }
}
