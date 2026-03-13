import 'dart:convert';
import 'dart:nativewrappers/_internal/vm/lib/ffi_patch.dart';

class UserModel {
  final String id;
  final String firstName;
  final String lastName;
  final String username;
  final String email;
  final List<String> preferences;
  final Map<String, List<String>> schedule;



  UserModel({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.username,
    required this.email,
    required this.preferences,
    required this.schedule,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String? ?? '',
      firstName: json['firstName'] as String? ?? '',
      lastName: json['lastName'] as String? ?? '',
      username: json['username'] as String? ?? '',
      email: json['email'] as String? ?? '',
      preferences: (json['preferences'] as List<dynamic>?)
            ?.map((item) => item as String)
            .toList() ??
        [],
      schedule: (json['schedule'] as Map<String, dynamic>?)?.map(
          (key, value) => MapEntry(
            key,
            (value as List<dynamic>).map((item) => item as String).toList(),
          ),
        ) ??
        {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'firstName': firstName,
      'lastName': lastName,
      'username': username,
      'email': email,
      'preferences': preferences,
      'schedule': schedule,
    };
  }

}