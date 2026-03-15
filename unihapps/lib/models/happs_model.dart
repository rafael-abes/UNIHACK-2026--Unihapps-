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

  static String _refToId(dynamic v) {
    if (v == null) return '';
    if (v is DocumentReference) return v.id;
    if (v is String) return v;
    return v.toString();
  }

  factory HappsModel.fromMap(String id, Map<String, dynamic> map) {
    return HappsModel(
      id: id,
      organizerId: _refToId(map['organizer']),
      title: map['title'] as String? ?? '',
      when: (map['when'] as Timestamp?)?.toDate() ?? DateTime.now(),
      category: map['category'] as String? ?? '',
      location: map['where'] is GeoPoint
          ? map['where'] as GeoPoint
          : const GeoPoint(0, 0),
      participants: (map['participants'] as List<dynamic>? ?? [])
          .map((p) => _refToId(p))
          .toList(),
    );
  }

  Map<String, dynamic> toMap() {
    final db = FirebaseFirestore.instance;
    return {
      'organizer': db.doc('users/$organizerId'),
      'title': title,
      'when': Timestamp.fromDate(when),
      'category': category,
      'where': location,
      'participants': participants.map((p) => db.doc('users/$p')).toList(),
    };
  }
}