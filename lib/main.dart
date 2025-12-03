import 'package:flutter/material.dart';
import 'login.dart';
import 'signup.dart';
import 'home.dart';


void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

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
  