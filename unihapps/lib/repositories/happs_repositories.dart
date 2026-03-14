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
}