import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:guardianly/main.dart';
import './mock.dart'; // Ensure this import points to your mock file

void main() {
  // 1. Install the mock handler
  setupFirebaseAuthMocks();

  // 2. Initialize Firebase (this will now call our MockFirebasePlatform)
  setUpAll(() async {
    await Firebase.initializeApp();
  });

  testWidgets('App builds without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    expect(find.byType(MyApp), findsOneWidget);
  });
}