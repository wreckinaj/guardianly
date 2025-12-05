import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core_platform_interface/firebase_core_platform_interface.dart';

class MockFirebasePlatform extends FirebasePlatform {
  @override
  Future<FirebaseAppPlatform> initializeApp({
    String? name,
    FirebaseOptions? options,
  }) async {
    // The constructor now expects positional arguments: name, options
    return FirebaseAppPlatform(
      name ?? '[DEFAULT]',
      options ?? const FirebaseOptions(
        apiKey: 'mock_api_key',
        appId: 'mock_app_id',
        messagingSenderId: 'mock_sender_id',
        projectId: 'mock_project_id',
      ),
    );
  }

  // The 'apps' getter must return a List directly, not a Future
  @override
  List<FirebaseAppPlatform> get apps => [];

  // 'initializeCore' is no longer required to be overridden in newer versions
}

void setupFirebaseAuthMocks() {
  TestWidgetsFlutterBinding.ensureInitialized();
  
  // This replaces the default Pigeon implementation with our Mock
  FirebasePlatform.instance = MockFirebasePlatform();
}