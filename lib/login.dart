import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '/Components/textfield.dart';
import '/Components/logoname.dart';

class LoginPage extends StatelessWidget {
  LoginPage({super.key});

  final usernameController = TextEditingController();
  final passwordController = TextEditingController();

  // Updated loginUser method to use mock credentials for testing
  void loginUser(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    // MOCK CREDENTIALS
    const String mockEmail = "test@example.com";
    const String mockPassword = "password123";

    try {
      // Using mock credentials instead of text field input
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: mockEmail,
        password: mockPassword,
      );

      if (context.mounted) {
        Navigator.pop(context); // Pop loading
        // Navigate to home screen
        Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
      }
    } on FirebaseAuthException catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Login Failed'),
            content: Text('Mock login failed: ${e.message}\n\nMake sure "$mockEmail" exists in your Firebase Console.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const LogoName(),
                const SizedBox(height: 50),

                Container(
                  padding: const EdgeInsets.all(20),
                  margin: const EdgeInsets.symmetric(horizontal: 25),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(
                      color: Colors.grey.shade400,
                      width: 1,
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    children: [
                      // Note: These fields are now ignored by the loginUser method
                      MyTextField(
                        controller: usernameController,
                        hintText: 'Enter an Email (ignored in mock)',
                        obscureText: false,
                      ),

                      const SizedBox(height: 20),

                      MyTextField(
                        controller: passwordController,
                        hintText: 'Password (ignored in mock)',
                        obscureText: true,
                      ),

                      const SizedBox(height: 10),

                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 25.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            GestureDetector(
                              onTap: () {
                                Navigator.pushNamed(context, '/forgot_pw');
                              },
                              child: const Text(
                                'Forgot Password',
                                style: TextStyle(
                                  color: Colors.red,
                                  fontWeight: FontWeight.bold,
                                  decoration: TextDecoration.underline,
                                  decorationColor: Colors.red,
                                  decorationThickness: 2,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Login Button
                      GestureDetector(
                        onTap: () => loginUser(context),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.symmetric(horizontal: 25),
                          decoration: BoxDecoration(
                            color: Colors.black,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Center(
                            child: Text(
                              "Login (Mock)",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 10),
                      const Text(
                        "Using: test@example.com / password123",
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),

                      const SizedBox(height: 20),

                      // Don't have an account? Sign Up Now
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            "Don't have an account?",
                            style: TextStyle(
                              color: Colors.black,
                            ),
                          ),
                          const SizedBox(width: 4),

                          GestureDetector(
                            onTap: () {
                              Navigator.pushNamed(context, '/signup');
                            },
                            child: const Text(
                              'Sign Up Now',
                              style: TextStyle(
                                color: Colors.blue,
                                fontWeight: FontWeight.bold,
                                decoration: TextDecoration.underline,
                                decorationColor: Colors.blue,
                                decorationThickness: 2,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
