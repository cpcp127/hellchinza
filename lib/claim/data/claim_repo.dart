import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/claim_model.dart';

class ClaimRepo {
  ClaimRepo(this._db);

  final FirebaseFirestore _db;

  Future<void> createClaim({
    required String reporterUid,
    required ClaimTarget target,
    required List<String> reasons,
    required String detail,
  }) async {
    final ref = _db.collection('claims').doc();

    final trimmedDetail = detail.trim();

    final data = <String, dynamic>{
      'id': ref.id,
      'type': target.type.key,
      'targetId': target.targetId,
      'targetOwnerUid': target.targetOwnerUid,
      'reporterUid': reporterUid,
      'reasons': reasons,
      'detail': trimmedDetail.isEmpty ? null : trimmedDetail,
      'status': 'open',
      'snapshot': {'title': target.title, 'imageUrl': target.imageUrl},
      'parentId': target.parentId,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    await ref.set(data);
  }
}
