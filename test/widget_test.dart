import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart'; // Add this import
import 'package:guardianly/main.dart';
import './mock.dart'; // Add this import

void main() {
  // 1. Install the mock handler
  setupFirebaseAuthMocks();

  // 2. Initialize Firebase (now safe because of the mock)
  setUpAll(() async {
    await Firebase.initializeApp();
  });

  testWidgets('App builds without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    expect(find.byType(MyApp), findsOneWidget);
  });
}