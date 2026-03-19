import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../meet/domain/meet_model.dart';

class MeetHomeRepo {
  MeetHomeRepo(this._db);

  final FirebaseFirestore _db;

  Future<List<MeetModel>> fetchRecentActiveMeets({int limit = 12}) async {
    final chatSnap = await _db
        .collection('chatRooms')
        .where('type', isEqualTo: 'group')
        .orderBy('lastMessageAt', descending: true)
        .limit(limit * 2)
        .get();

    final meetIds = <String>[];
    for (final doc in chatSnap.docs) {
      final data = doc.data();
      final meetId = (data['meetId'] ?? '').toString();
      if (meetId.isNotEmpty && !meetIds.contains(meetId)) {
        meetIds.add(meetId);
      }
      if (meetIds.length >= limit) break;
    }

    return _fetchMeetsByIds(meetIds);
  }

  Future<List<MeetModel>> fetchPopularMeets({int limit = 12}) async {
    const candidateSize = 40;

    final snap = await _db
        .collection('meets')
        .where('status', isEqualTo: 'open')
        .orderBy('createdAt', descending: true)
        .limit(candidateSize)
        .get();

    final meets = snap.docs.map((e) => MeetModel.fromDoc(e)).toList();

    final counted = await Future.wait(
      meets.map((meet) async {
        try {
          final countSnap = await _db
              .collection('meets')
              .doc(meet.id)
              .collection('members')
              .count()
              .get();

          return (meet: meet, memberCount: countSnap.count ?? 0);
        } catch (_) {
          return (meet: meet, memberCount: 0);
        }
      }),
    );

    counted.sort((a, b) => b.memberCount.compareTo(a.memberCount));

    return counted.take(limit).map((e) => e.meet).toList();
  }

  Future<List<MeetModel>> fetchNewestMeets({int limit = 12}) async {
    final snap = await _db
        .collection('meets')
        .where('status', isEqualTo: 'open')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();

    return snap.docs.map((e) => MeetModel.fromDoc(e)).toList();
  }

  Future<List<MeetModel>> fetchInterestMeets({int limit = 12}) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return [];

    final userDoc = await _db.collection('users').doc(uid).get();
    final data = userDoc.data();
    if (data == null) return [];

    final categories = (data['category'] as List?)
        ?.map((e) => e.toString())
        .where((e) => e.isNotEmpty)
        .toList() ??
        [];

    if (categories.isEmpty) return [];

    final result = <MeetModel>[];
    final addedIds = <String>{};

    for (final category in categories.take(3)) {
      final snap = await _db
          .collection('meets')
          .where('status', isEqualTo: 'open')
          .where('category', isEqualTo: category)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      for (final doc in snap.docs) {
        final meet = MeetModel.fromDoc(doc);
        if (addedIds.add(meet.id)) {
          result.add(meet);
        }
      }
    }

    return result.take(limit).toList();
  }

  Future<List<MeetModel>> fetchLightningHotMeets({int limit = 12}) async {
    final lightningSnap = await _db
        .collectionGroup('lightnings')
        .orderBy('createdAt', descending: true)
        .limit(limit * 3)
        .get();

    final meetIds = <String>[];
    for (final doc in lightningSnap.docs) {
      final data = doc.data();
      final meetId = (data['meetId'] ?? '').toString();
      if (meetId.isNotEmpty && !meetIds.contains(meetId)) {
        meetIds.add(meetId);
      }
      if (meetIds.length >= limit) break;
    }

    return _fetchMeetsByIds(meetIds);
  }

  Future<List<MeetModel>> _fetchMeetsByIds(List<String> meetIds) async {
    if (meetIds.isEmpty) return [];

    final result = <MeetModel>[];
    final chunks = _chunk(meetIds, 10);

    for (final ids in chunks) {
      final snap = await _db
          .collection('meets')
          .where(FieldPath.documentId, whereIn: ids)
          .get();

      final items = snap.docs
          .map((e) => MeetModel.fromDoc(e))
          .where((e) => e.status == 'open')
          .toList();

      result.addAll(items);
    }

    final orderMap = <String, int>{
      for (int i = 0; i < meetIds.length; i++) meetIds[i]: i,
    };

    result.sort((a, b) {
      final aOrder = orderMap[a.id] ?? 9999;
      final bOrder = orderMap[b.id] ?? 9999;
      return aOrder.compareTo(bOrder);
    });

    return result;
  }

  List<List<String>> _chunk(List<String> list, int size) {
    final result = <List<String>>[];
    for (int i = 0; i < list.length; i += size) {
      final end = (i + size < list.length) ? i + size : list.length;
      result.add(list.sublist(i, end));
    }
    return result;
  }
}