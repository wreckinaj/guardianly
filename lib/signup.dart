import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '/Components/textfield.dart';
import '/Components/logoname.dart';

class SignUpPage extends StatelessWidget {
  SignUpPage({super.key});

  final usernameController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  void signUpUser(BuildContext context) async {
    // 1. Basic Validation
    if (passwordController.text != confirmPasswordController.text) {
      showDialog(
        context: context,
        builder: (context) => const AlertDialog(title: Text("Passwords don't match")),
      );
      return;
    }

    // 2. Show Loading Indicator
    showDialog(
      context: context,
      barrierDismissible: false, // Prevent user from dismissing by tapping outside
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // 3. Create User in Firebase Auth
      UserCredential userCredential = 
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: usernameController.text.trim(),
        password: passwordController.text.trim(),
      );

      // 4. Store Account Preferences in Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userCredential.user!.uid)
          .set({
        'email': usernameController.text.trim(),
        'created_at': FieldValue.serverTimestamp(),
        'preferences': {
          'notifications_enabled': true,
          'theme': 'light',
        }
      });

      // 5. Success! Navigate away.
      if (context.mounted) {
        Navigator.pop(context); // Pop loading circle
        Navigator.pop(context); // Go back to login
      }
      
    } on FirebaseAuthException catch (e) {
      // Handle Auth specific errors (weak password, email already in use)
      if (context.mounted) {
        Navigator.pop(context); // Pop loading
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text("Sign Up Error"),
            content: Text(e.message ?? "An authentication error occurred."),
          ),
        );
      }
    } on FirebaseException catch (e) {
      // Handle Firestore specific errors (permission denied, not found)
      if (context.mounted) {
        Navigator.pop(context); // Pop loading
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text("Database Error"),
            content: Text("${e.plugin}: ${e.message}"), // Helpful debug info
          ),
        );
      }
    } catch (e) {
      // Handle any other unexpected errors
      if (context.mounted) {
        Navigator.pop(context); // Pop loading
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text("Unknown Error"),
            content: Text(e.toString()),
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
                      MyTextField(
                        controller: usernameController,
                        hintText: 'Enter an Email',
                        obscureText: false,
                      ),
                      const SizedBox(height: 20),
                      MyTextField(
                        controller: passwordController,
                        hintText: 'Password',
                        obscureText: true,
                      ),
                      const SizedBox(height: 10),
                      MyTextField(
                        controller: confirmPasswordController,
                        hintText: 'Confirm Password',
                        obscureText: true,
                      ),
                      const SizedBox(height: 50),
                      GestureDetector(
                        onTap: () => signUpUser(context),
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          margin: const EdgeInsets.symmetric(horizontal: 70),
                          decoration: BoxDecoration(
                            color: Colors.black,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Center(
                            child: Text(
                              "Sign Up",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 30),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            "Already have an account?",
                            style: TextStyle(color: Colors.black),
                          ),
                          const SizedBox(width: 4),
                          GestureDetector(
                            onTap: () {
                              Navigator.pushNamed(context, '/login');
                            },
                            child: const Text(
                              'Login',
                              style: TextStyle(
                                color: Colors.blue,
                                fontWeight: FontWeight.bold,
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