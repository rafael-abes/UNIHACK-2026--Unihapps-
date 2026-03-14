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
    return List<String>.from(data["friendsList"] ?? []);
  }

  Future<void> updateUserStatus(String userId, String status) async {
    await _firestore.users.doc(userId).update({'status': status});
  }

}