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

  // Send a friend request
  Future<void> sendFriendRequest(String currentUid, String targetUid) async {
    // Add to current user's sentRequests
    await _firestore.users.doc(currentUid).update({
      'sentRequests': FieldValue.arrayUnion([targetUid]),
    });

    // Add to target user's friendRequests
    await _firestore.users.doc(targetUid).update({
      'friendRequests': FieldValue.arrayUnion([currentUid]),
    });
  }

  // Accept a friend request
  Future<void> acceptFriendRequest(
    String currentUid,
    String requesterUid,
  ) async {
    // Add each other as friends
    await _firestore.users.doc(currentUid).update({
      'friends': FieldValue.arrayUnion([requesterUid]),
      'friendRequests': FieldValue.arrayRemove([requesterUid]),
    });

    await _firestore.users.doc(requesterUid).update({
      'friends': FieldValue.arrayUnion([currentUid]),
      'sentRequests': FieldValue.arrayRemove([currentUid]),
    });
  }

  // Decline a friend request
  Future<void> declineFriendRequest(
    String currentUid,
    String requesterUid,
  ) async {
    await _firestore.users.doc(currentUid).update({
      'friendRequests': FieldValue.arrayRemove([requesterUid]),
    });

    await _firestore.users.doc(requesterUid).update({
      'sentRequests': FieldValue.arrayRemove([currentUid]),
    });
  }

  // Cancel a sent request
  Future<void> cancelFriendRequest(String currentUid, String targetUid) async {
    await _firestore.users.doc(currentUid).update({
      'sentRequests': FieldValue.arrayRemove([targetUid]),
    });

    await _firestore.users.doc(targetUid).update({
      'friendRequests': FieldValue.arrayRemove([currentUid]),
    });
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
