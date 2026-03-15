import '../models/happs_model.dart';
import '../services/firestore_service.dart';

class HappRepository {
  final FirestoreService _firestore = FirestoreService();

  Future<void> createHapp(HappsModel happ) async {
    await _firestore.happs.add(happ.toMap());
  }

  Future<void> deleteHapp(String happId) async {
    await _firestore.happs.doc(happId).delete();
  }

  Future<void> updateHapp(String happId, Map<String, dynamic> data) async {
    await _firestore.happs.doc(happId).update(data);
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
