import 'dart:convert';

class UserModel {
  final String id;
  final String firstName;
  final String lastName;
  final String username;
  final String email;
  final List<String> preferences;
  final List<String> friendsList;
  final Map<String, List<String>> schedule;

  UserModel({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.username,
    required this.email,
    required this.preferences,
    required this.friendsList,
    required this.schedule,
  });

  factory UserModel.fromMap(String id, Map<String, dynamic> map) {
    return UserModel(
      id: id,
      firstName: map['firstName'] as String? ?? '',
      lastName: map['lastName'] as String? ?? '',
      username: map['username'] as String? ?? '',
      email: map['email'] as String? ?? '',
      preferences: List<String>.from(map['preferences'] ?? []),
      friendsList: List<String>.from(map['friendsList'] ?? []),
      schedule: (map['schedule'] as Map<String, dynamic>?)?.map(
            (key, value) => MapEntry(
              key,
              List<String>.from(value),
            ),
          ) ??
          {},
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'firstName': firstName,
      'lastName': lastName,
      'username': username,
      'email': email,
      'preferences': preferences,
      'friendsList': friendsList,
      'schedule': schedule,
    };
  }
}