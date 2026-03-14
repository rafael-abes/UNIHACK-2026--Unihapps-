import 'dart:convert';

class UserModel {
  final String id;
  final String firstName;
  final String lastName;
  final String username;
  final String email;
  final String phone;
  final List<String> friends;
  final List<String> preferences;
  final List<String> friendsList;
  final Map<String, List<String>> schedule;

  UserModel({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.username,
    required this.email,
    required this.phone,
    required this.friends,
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
      phone: map['phone'] as String? ?? '',
      friends: List<String>.from(map['friends'] ?? []),
      preferences: List<String>.from(map['preferences'] ?? []),
      schedule:
          (map['schedule'] as Map<String, dynamic>?)?.map(
            (key, value) => MapEntry(key, List<String>.from(value)),
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
      'phone': phone,
      'friends': friends,
      'preferences': preferences,
      'friendsList': friendsList,
      'schedule': schedule,
    };
  }
}
