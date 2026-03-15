import 'package:cloud_firestore/cloud_firestore.dart';

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

  factory HappsModel.fromMap(String id, Map<String, dynamic> map) {
    return HappsModel(
      id: id,
      organizerId: map['organizerId'] as String? ?? '',
      title: map['title'] as String? ?? '',
      when: (map['when'] as Timestamp?)?.toDate() ?? DateTime.now(),
      category: map['category'] as String? ?? '',
      location: map['where'] as GeoPoint? ?? GeoPoint(0, 0),
      participants: List<String>.from(map['participants'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'organizerId': organizerId,
      'title': title,
      'when': Timestamp.fromDate(when),
      'category': category,
      'where': location,
      'participants': participants,
    };
  }
}