import 'package:cloud_firestore/cloud_firestore.dart';
import 'domain/claim_model.dart';

class ClaimService {
  ClaimService(this._db);
  final FirebaseFirestore _db;

  Future<void> createClaim({
    required String reporterUid,
    required ClaimTarget target,
    required List<String> reasons,
    required String detail,
  }) async {
    final ref = _db.collection('claims').doc();

    final data = <String, dynamic>{
      'id': ref.id,
      'type': target.type.key,
      'targetId': target.targetId,
      'targetOwnerUid': target.targetOwnerUid,
      'reporterUid': reporterUid,
      'reasons': reasons,
      'detail': detail.trim().isEmpty ? null : detail.trim(),
      'status': 'open',
      'snapshot': {
        'title': target.title,
        'imageUrl': target.imageUrl,
      },
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    await ref.set(data);
  }
}
