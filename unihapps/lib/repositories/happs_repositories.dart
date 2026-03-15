import '../models/happs_model.dart';
import '../services/firestore_service.dart';

class HappRepository {
  final FirestoreService _firestore = FirestoreService();

  Future<void> createHapp(HappsModel happ) async {
    print('[HAPPS] createHapp called — title: ${happ.title}, organizerId: ${happ.organizerId}');
    try {
      await _firestore.happs.add(happ.toMap());
      print('[HAPPS] createHapp success');
    } catch (e, st) {
      print('[HAPPS] createHapp ERROR: $e\n$st');
      rethrow;
    }
  }

  Future<void> deleteHapp(String happId) async {
    print('[HAPPS] deleteHapp called — id: $happId');
    try {
      await _firestore.happs.doc(happId).delete();
      print('[HAPPS] deleteHapp success');
    } catch (e, st) {
      print('[HAPPS] deleteHapp ERROR: $e\n$st');
      rethrow;
    }
  }

  Future<void> updateHapp(String happId, Map<String, dynamic> data) async {
    print('[HAPPS] updateHapp called — id: $happId, data keys: ${data.keys.toList()}');
    try {
      await _firestore.happs.doc(happId).update(data);
      print('[HAPPS] updateHapp success');
    } catch (e, st) {
      print('[HAPPS] updateHapp ERROR: $e\n$st');
      rethrow;
    }
  }

  Future<List<HappsModel>> getHappsForUser(String userId) async {
  final snapshot = await _firestore.happs
      .where('participants', arrayContains: userId)
      .get();
  return snapshot.docs
      .map((doc) => HappsModel.fromMap(doc.id, doc.data() as Map<String, dynamic>))
      .toList();
}
}
