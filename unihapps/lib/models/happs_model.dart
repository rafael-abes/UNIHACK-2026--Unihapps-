import 'dart:convert';
import 'dart:nativewrappers/_internal/vm/lib/ffi_patch.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Import Firestore package

class HappsModel {
  final String id;
  final String organizerId;
  final String title;
  final DateTime when;
  final String category;
  final GeoPoint location;
  final List<String> participants;


  HappsModel({
    required this.id,
    required this.organizerId,
    required this.title,
    required this.when,
    required this.category,
    required this.location,
    required this.participants,
  });

  factory HappsModel.fromJson(Map<String, dynamic> json) {
    return HappsModel(
      id: json['id'] as String? ?? '',
      organizerId: json['organizerId'] as String? ?? '',
      title: json['title'] as String? ?? '',
      when: json['when'] as DateTime? ?? DateTime.now(),
      category: json['category'] as String? ?? '',
      location: json['location'] as GeoPoint? ?? GeoPoint(0, 0),
      participants:json['participants'] != null
          ? List<String>.from(json['participants'])
          : [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'organizerId': organizerId,
      'title': title,
      'when': when,
      'category': category,
      'location': location,
      'participants': participants,
    };
  }

}