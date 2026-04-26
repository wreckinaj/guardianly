import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '/Components/menu.dart';
import '/login.dart';

class Profile extends StatefulWidget {
  const Profile({super.key});

  @override
  State<Profile> createState() => _ProfileState();
}

class _ProfileState extends State<Profile> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  String _username = "";
  String _email = "";
  bool _isLoading = true;
  
  @override
  void initState() {
    super.initState();
    _loadUserData();
  }
  
  Future<void> _loadUserData() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
    });
    
    final User? currentUser = _auth.currentUser;
    
    if (currentUser != null) {
      _email = currentUser.email ?? "No email";
      
      try {
        DocumentSnapshot userDoc = await _firestore
            .collection('users')
            .doc(currentUser.uid)
            .get();
        
        if (!mounted) return;
        
        if (userDoc.exists && userDoc.data() != null) {
          final data = userDoc.data() as Map<String, dynamic>;
          setState(() {
            _username = data['username'] ?? currentUser.email?.split('@')[0] ?? "User";
          });
        } else {
          setState(() {
            _username = currentUser.email?.split('@')[0] ?? "User";
          });
        }
      } catch (e) {
        debugPrint("Error loading user data: $e");
        if (!mounted) return;
        setState(() {
          _username = currentUser.email?.split('@')[0] ?? "User";
        });
      }
    }
    
    if (!mounted) return;
    setState(() {
      _isLoading = false;
    });
  }
  
  Future<void> _updateUsername() async {
    TextEditingController controller = TextEditingController(text: _username);
    
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change Username'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Enter new username',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    
    if (result == true && mounted) {
      String newUsername = controller.text.trim();
      if (newUsername.isNotEmpty && _auth.currentUser != null) {
        try {
          await _firestore
              .collection('users')
              .doc(_auth.currentUser!.uid)
              .update({
            'username': newUsername,
          });
          
          if (mounted) {
            setState(() {
              _username = newUsername;
            });
            
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Username updated!')),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error: $e')),
            );
          }
        }
      }
    }
  }
  
  Future<void> _changePassword() async {
    final User? currentUser = _auth.currentUser;
    if (currentUser == null || currentUser.email == null) return;
    
    try {
      await _auth.sendPasswordResetEmail(email: currentUser.email!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password reset email sent! Check your inbox.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }
  
  Future<void> _deleteAccount() async {
    final User? currentUser = _auth.currentUser;
    if (currentUser == null) return;
    
    try {
      await _firestore.collection('users').doc(currentUser.uid).delete();
      await currentUser.delete();
      await _auth.signOut();
      
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => LoginPage()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting account: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: const Menu(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Column(
                children: [
                  const CircleAvatar(
                    radius: 60,
                    backgroundColor: Colors.blue,
                    child: Icon(
                      Icons.person,
                      size: 60,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 30),
                  
                  _buildInfoRow(
                    label: "Username",
                    value: _username,
                    onEdit: _updateUsername,
                  ),
                  
                  const Divider(height: 1, indent: 20, endIndent: 20),
                  
                  _buildInfoRow(
                    label: "Email",
                    value: _email,
                  ),
                  
                  const Divider(height: 1, indent: 20, endIndent: 20),
                  
                  _buildInfoRow(
                    label: "Password",
                    value: "••••••••",
                    onEdit: _changePassword,
                  ),
                  
                  const SizedBox(height: 30),
                  
                  // Delete Account Button with Box
                  _buildDeleteButton(),
                ],
              ),
            ),
    );
  }
  
  Widget _buildInfoRow({
    required String label,
    required String value,
    VoidCallback? onEdit,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[700],
                letterSpacing: label == "Password" ? 3 : 0,
              ),
              textAlign: TextAlign.right,
            ),
          ),
          if (onEdit != null) ...[
            const SizedBox(width: 12),
            InkWell(
              onTap: onEdit,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.edit,
                  size: 18,
                  color: Colors.blue,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDeleteButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.red,
          border: Border.all(
            color: Colors.red,
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: TextButton(
          onPressed: () {
            _showDeleteAccountDialog();
          },
          style: TextButton.styleFrom(
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          child: const Text(
            "Delete Account",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
  
  void _showDeleteAccountDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text(
          "Are you sure you want to delete your account?",
          textAlign: TextAlign.center,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        content: const Text(
          "This action is permanent and cannot be undone.",
          textAlign: TextAlign.center,
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
                    onPressed: () => Navigator.of(context).pop(),
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
                    onPressed: () {
                      Navigator.of(context).pop();
                      _deleteAccount();
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
                      "Delete",
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
      ),
    );
  }
}
