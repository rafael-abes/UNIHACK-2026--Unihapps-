import 'dart:convert';

import 'package:flutter/scheduler.dart';

class UserModel {
  final String id;
  final String firstName;
  final String lastName;
  final String username;
  final String email;
  final String phone;
  final List<String> friends;
  final List<String> friendRequests;
  final List<String> sentRequests;
  final List<String> preferences;
  final Map<String, List<String>> schedule;
  final String status;
  final String fcmToken;

  UserModel({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.username,
    required this.email,
    required this.phone,
    required this.friends,
    required this.preferences,
    required this.schedule,
    this.status = 'offline',
    required this.fcmToken,
    required this.friendRequests,
    required this.sentRequests,
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
      friendRequests: List<String>.from(map['friendRequests'] ?? []),
      sentRequests: List<String>.from(map['sentRequests'] ?? []),
      schedule:
          (map['schedule'] as Map<String, dynamic>?)?.map(
            (key, value) => MapEntry(key, List<String>.from(value)),
          ) ??
          {},
          status: map['status'] as String? ?? 'offline',
          fcmToken: map['fcmToken'] as String? ?? '',
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
      'friendRequests': friendRequests,
      'sentRequests': sentRequests,
      'schedule': schedule,
      'status': status,
      'fcmToken': fcmToken, // ← add this
    };
  }
}
