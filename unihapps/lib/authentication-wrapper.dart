import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'pages/welcome.dart';
// import 'pages/home_page.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (BuildContext context, AsyncSnapshot<User?> snapshot) {
        // error state
        if (snapshot.hasError) {
          return const Scaffold(
            body: Center(child: Text('Something went wrong')),
          );
        }

        // loading state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // logged out
        if (!snapshot.hasData) {
          return const WelcomePage();
        }

        // logged in — pass uid to HomePage if needed
        final user = snapshot.data!;
        return WelcomePage();
      },
    );
  }
}
