import 'package:flutter/material.dart';
import '/Components/textfield.dart';
import '/Components/logoname.dart';
import '/services/api_service.dart';
import '/confirmation_page.dart';
// Followed tutorial on youtube: https://youtu.be/Dh-cTQJgM-Q?si=vpDDOYUqS0LrhRcU




class LoginPage extends StatelessWidget {
  LoginPage({super.key});


  //text editing controllers
  final usernameController = TextEditingController();
  final passwordController = TextEditingController();

  //login user in method
  void loginUser(BuildContext context) async {
    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    // Call API
    final result = await ApiService.login(
      usernameController.text,
      passwordController.text,
    );

    // Close loading indicator
    if (context.mounted) Navigator.pop(context);

    // Handle result
    if (result['success']) {
      // Login successful
      final userData = result['data'];
      if (context.mounted) {
        // Navigate to confirmation page
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ConfirmationPage(
              message: 'Login Successful!',
              userName: userData['user']['username'],
              isSuccess: true,
            ),
          ),
        );
      }
    } else {
      // Login failed
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['error']),
            backgroundColor: Colors.red,
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
              const SizedBox(height:50),


              Container(
                padding: const EdgeInsets.all(20),
                margin: const EdgeInsets.symmetric(horizontal: 25),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border:Border.all(
                    color: Colors.grey.shade400,
                    width: 1,
                  ),
                borderRadius: BorderRadius.circular(20),
              ),

              child: Column(
                children:[
                // username text field
                  MyTextField(
                    controller: usernameController,
                    hintText: 'Enter an Email',
                    obscureText: false,
                  ),

                  const SizedBox(height:20),

                  // password text field
                  MyTextField(
                    controller: passwordController,
                    hintText: 'Password',
                    obscureText: true,
                  ),

                  const SizedBox(height:10),

                  // forgot password?
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 25.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          'Forgot Password?',
                          style: TextStyle(
                            color: Colors.red,
                          ),
                        ),
                      ],
                    )
                  ),

                  const SizedBox(height:50),

                  // Login Button
                  GestureDetector(
                    onTap: () => loginUser(context),
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      margin: const EdgeInsets.symmetric(horizontal: 70),
                      decoration: BoxDecoration(
                        color: Colors.black,
                        // edit border edge roundness
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Center(
                        child: Text(
                          "Login",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height:30),

                  // Don't have an account? Sign Up Now
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        "Don't have an account?",
                        style: TextStyle(
                          color: Colors.black,),
                      ),
                      const SizedBox(width: 4),

                      GestureDetector(
                        onTap: (){
                          Navigator.pushNamed(context, '/signup');
                        },
                        child: const Text(
                          'Sign Up Now',
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
      ),),
    );
  }
}
