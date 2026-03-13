import 'package:flutter/material.dart';

class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'UniHapps',
              style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 48),
            SizedBox(
              width: 220,
              child: ElevatedButton(
                onPressed: () {},
                child: const Text('Log In'),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: 220,
              child: OutlinedButton(
                onPressed: () {},
                child: const Text('Sign Up'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
