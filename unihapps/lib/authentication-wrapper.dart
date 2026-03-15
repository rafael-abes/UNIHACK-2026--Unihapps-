import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:unihapps/pages/friends_list.dart';
import 'package:unihapps/pages/sign_up.dart';
import 'pages/welcome.dart';
import 'models/user_model.dart';
import 'repositories/user_repositories.dart';
import 'pages/home_page.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

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
        _ensureUserDocument(snapshot.data!);
        return const HomePage();
      },
    );
  }

  Future<void> _ensureUserDocument(User user) async {
    final _userRepository = UserRepository();
    final existingUser = await _userRepository.getUser(user.uid);

    if (existingUser == null) {
      final token = await FirebaseMessaging.instance.getToken() ?? '';

      final newUser = UserModel(
        id: user.uid,
        firstName: user.displayName?.split(' ').first ?? '',
        lastName: user.displayName?.split(' ').last ?? '',
        username: '',
        email: user.email ?? '',
        phone: '',
        friends: [],
        friendRequests: [], // ← make sure these are here
        sentRequests: [],
        preferences: [],
        schedule: {},
        fcmToken: token, // ← add this
      );
      await _userRepository.createUser(newUser);
    }
  }
}
