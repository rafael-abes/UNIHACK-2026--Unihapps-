import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/group_model.dart';
import '../services/firestore_service.dart';

class GroupRepository {
  final _firestore = FirebaseFirestore.instance;

  // Create a new group
  Future<String> createGroup(GroupModel group) async {
    final ref = await _firestore.collection('groups').add(group.toMap());
    return ref.id;
  }

  // Get a single group
  Future<GroupModel?> getGroup(String groupId) async {
    final doc = await _firestore.collection('groups').doc(groupId).get();
    if (!doc.exists) return null;
    return GroupModel.fromMap(doc.id, doc.data()!);
  }

  // Get all groups the current user is in
  Stream<List<GroupModel>> getUserGroups(String uid) {
    return _firestore
        .collection('groups')
        .where('members', arrayContains: uid)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => GroupModel.fromMap(doc.id, doc.data()))
            .toList());
  }

  // Add a member to a group — any existing member can do this
  Future<void> addMember(String groupId, String uid) async {
    await _firestore.collection('groups').doc(groupId).update({
      'members': FieldValue.arrayUnion([uid]),
    });
  }

  // Remove a member — admins only
  Future<void> removeMember(String groupId, String uid) async {
    await _firestore.collection('groups').doc(groupId).update({
      'members': FieldValue.arrayRemove([uid]),
      'admins': FieldValue.arrayRemove([uid]),
    });
  }

  // Delete group — creator only
  Future<void> deleteGroup(String groupId) async {
    await _firestore.collection('groups').doc(groupId).delete();
  }

  // Update group name/description
  Future<void> updateGroup(String groupId, Map<String, dynamic> data) async {
    await _firestore.collection('groups').doc(groupId).update(data);
  }
}