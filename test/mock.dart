import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void setupFirebaseAuthMocks() {
  // 1. Ensure the testing binding is initialized
  TestWidgetsFlutterBinding.ensureInitialized();

  // 2. Define the channel used by Firebase Core
  const MethodChannel channel = MethodChannel('plugins.flutter.io/firebase_core');

  // 3. Mock the method call handler
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
    channel,
    (MethodCall methodCall) async {
      // Mock 'initializeCore': Returns a list of initialized apps (initially empty or default)
      if (methodCall.method == 'Firebase#initializeCore') {
        return [
          {
            'name': '[DEFAULT]',
            'options': {
              'apiKey': '123',
              'appId': '123',
              'messagingSenderId': '123',
              'projectId': '123',
            },
            'pluginConstants': {},
          }
        ];
      }

      // Mock 'initializeApp': Returns success with dummy options
      if (methodCall.method == 'Firebase#initializeApp') {
        return {
          'name': methodCall.arguments['appName'],
          'options': methodCall.arguments['options'],
          'pluginConstants': {},
        };
      }

      return null;
    },
  );
}