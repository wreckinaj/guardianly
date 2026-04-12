// https://youtu.be/kL5WrxyexzA?si=eKY34nKAVH7SC9hY

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class Menu extends StatelessWidget implements PreferredSizeWidget {
  const Menu({super.key});

  // definition of the dialog with the new formatting
  void _showDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: const Text(
            "Are you sure you want to logout?",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
          actions: [
            const Divider(height: 1, thickness: 1),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(color: Colors.grey.shade300),
                        ),
                      ),
                      child: const Text(
                        "Cancel",
                        style: TextStyle(
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextButton(
                      onPressed: () async {
                        // Add Firebase logout authentication here
                        try {
                          await FirebaseAuth.instance.signOut();
                          
                          // Close the dialog
                          if (context.mounted) {
                            Navigator.of(context).pop();
                            
                            // Navigate to login page and remove all previous routes
                            Navigator.pushNamedAndRemoveUntil(
                              context, 
                              '/login', 
                              (route) => false,
                            );
                          }
                        } catch (e) {
                          // Handle error if sign out fails
                          if (context.mounted) {
                            Navigator.of(context).pop(); // Close dialog
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error signing out: $e')),
                            );
                          }
                        }
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.red,
                        backgroundColor: Colors.red.withValues(alpha: 0.1),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        "Logout",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.white,
      title: GestureDetector(
        onTap: () {
          // Navigate to home screen
          // If already on home, do nothing
          // If not on home, navigate to it
          Navigator.pushNamedAndRemoveUntil(
            context, 
            '/home', 
            (route) => false,
          );
        },
        child: const Text(
          'Guardianly',
          style: TextStyle(
            fontFamily: 'Roboto', // system default font
            color: Color.fromARGB(255, 27, 27, 27),
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
      ),
      centerTitle: false,
      
      actions:[
        PopupMenuButton<int>(
          color: Colors.white,
          offset: const Offset(0, 50),
          onSelected:(value) {
            if (value == 1) {
              Navigator.pushNamed(context, '/profile');
            }
            else if (value == 2) {
              Navigator.pushNamed(context, '/saved'); 
            }
            else if (value == 3) {
              Navigator.pushNamed(context, '/settings');
            }
            else if (value == 4) {
              _showDialog(context); 
            }
          },
          itemBuilder: (context) =>[
            const PopupMenuItem(
              value: 1,
              child: Text('Profile'),
            ),

            const PopupMenuItem(
              value: 2,
              child: Text('History & Saved'),
            ),

            const PopupMenuItem(
              value: 3,
              child: Text('Settings'),
            ),

            const PopupMenuItem(
              value: 4,
              child: Text('Logout'),
            ),
          ],
        ),
      ],
    );
  }
  
  // Required because AppBar implements PreferredSizeWidget
  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
