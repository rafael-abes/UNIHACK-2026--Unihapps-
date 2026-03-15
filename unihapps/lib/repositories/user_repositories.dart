import '../models/user_model.dart';
import '../services/firestore_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UserRepository {
  final FirestoreService _firestore = FirestoreService();

  Future<void> createUser(UserModel user) async {
    await _firestore.users.doc(user.id).set(user.toMap());
  }

  Future<UserModel?> getUser(String id) async {
    final doc = await _firestore.users.doc(id).get();

    if (!doc.exists) return null;

    return UserModel.fromMap(doc.id, doc.data() as Map<String, dynamic>);
  }

  Future<List<String>> getFriends(String uid) async {
    final doc = await _firestore.users.doc(uid).get();

    if (!doc.exists) return [];

    final data = doc.data() as Map<String, dynamic>;
    return List<String>.from(data["friends"] ?? []);
  }

  Future<void> updateUserStatus(String userId, String status) async {
    await _firestore.users.doc(userId).update({'status': status});
  }

  Future<void> updateUserLocation(String userId, double lat, double lng) async {
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        "location.coords": GeoPoint(lat, lng),
        "location.updatedAt": FieldValue.serverTimestamp(),
      });
    }

  Stream<List<UserModel>> streamFriendsLocations(List<String> friendIds) {
    return FirebaseFirestore.instance
        .collection('users')
        .where(FieldPath.documentId, whereIn: friendIds)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => UserModel.fromMap(doc.id, doc.data()))
          .toList();
    });
  }

}