// https://youtu.be/kL5WrxyexzA?si=eKY34nKAVH7SC9hY

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';


class Menu extends StatelessWidget implements PreferredSizeWidget {
  const Menu({super.key});



  // definition of the dialog
  void _showDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          
          title: const Text("Verification"),
          content: const Text("You have pressed the logout button. Are you sure you want to logout?"),
          
          actions: [
            // cancel button
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: const Color.fromARGB(255, 109, 106, 106),
              ),
              child: const Text("Cancel"),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),

            //logout button
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: const Color.fromARGB(255, 215, 32, 19),
              ),
              child: const Text("Logout"),
              onPressed: () {
                // add logout authentication here
                Navigator.of(context).pop();
              },
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
      title: const Text(
        'Guardianly',
          style: TextStyle(
            fontFamily: 'Roboto', // system default font
            color: Color.fromARGB(255, 27, 27, 27),
            fontWeight: FontWeight.bold,
            fontSize: 24,
        ),
      ),
        centerTitle: false,
        
        actions:[
          PopupMenuButton<int>(
            color: Colors.white,
            offset: const Offset(0, 50),
            onSelected:(value) {
              if (value == 4) {
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

