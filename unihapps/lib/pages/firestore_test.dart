import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreTestPage extends StatelessWidget {
  const FirestoreTestPage({super.key});

  Future<void> addTestUser() async {
    try {
      await FirebaseFirestore.instance.collection('users').add({
        'firstName': 'John',
        'lastName': 'Doe',
        'username': 'johndoe',
        'email': 'johndoe@example.com',
        'preferences': ['sports', 'music'],
        'schedule': {
          'mon': ['Math', 'Physics'],
          'tues': ['Chemistry', 'Biology'],
        },
      });
      debugPrint('Test user added successfully!');
    } catch (e) {
      debugPrint('Failed to add test user: $e');
    }
  }

  Future<void> addTestHapp() async {
    try {
      await FirebaseFirestore.instance.collection('happs').add({
        'organizerId': '12345',
        'title': 'Hackathon 2026',
        'when': Timestamp.now(),
        'category': 'Tech',
        'location': const GeoPoint(37.7749, -122.4194),
        'participants': ['user1', 'user2'],
      });
      debugPrint('Test happ added successfully!');
    } catch (e) {
      debugPrint('Failed to add test happ: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Firestore Test')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: addTestUser,
              child: const Text('Add Test User'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: addTestHapp,
              child: const Text('Add Test Happ'),
            ),
          ],
        ),
      ),
    );
  }
}
