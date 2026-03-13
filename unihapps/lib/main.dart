import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Import Firestore
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'UniHapps',
      home: Scaffold(
        appBar: AppBar(title: const Text('UniHapps')),
        body: const FirestoreTestWidget(), // Add Firestore test widget
      ),
    );
  }
}

class FirestoreTestWidget extends StatelessWidget {
  const FirestoreTestWidget({super.key});

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
        'location': const GeoPoint(37.7749, -122.4194), // Example GeoPoint
        'participants': ['user1', 'user2'],
      });
      debugPrint('Test happ added successfully!');
    } catch (e) {
      debugPrint('Failed to add test happ: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ElevatedButton(
            onPressed: addTestUser,
            child: const Text('Add Test User'),
          ),
          ElevatedButton(
            onPressed: addTestHapp,
            child: const Text('Add Test Happ'),
          ),
        ],
      ),
    );
  }
}