import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

import '../../feed/domain/feed_place.dart';
import '../domain/lightning_model.dart';
import '../domain/meet_model.dart';
import '../domain/meet_region.dart';
import '../domain/meet_summary_model.dart';

class MeetDetailPayload {
  final MeetModel meet;
  final bool isMember;
  final int memberCount;
  final String? myRequestStatus;

  const MeetDetailPayload({
    required this.meet,
    required this.isMember,
    required this.memberCount,
    required this.myRequestStatus,
  });
}

class MeetRepo {
  MeetRepo({
    FirebaseFirestore? db,
    FirebaseAuth? auth,
    FirebaseStorage? storage,
  })  : _db = db ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _storage = storage ?? FirebaseStorage.instance;

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;
  final FirebaseStorage _storage;

  String? get currentUid => _auth.currentUser?.uid;

  DocumentReference<Map<String, dynamic>> meetRef(String meetId) {
    return _db.collection('meets').doc(meetId);
  }

  CollectionReference<Map<String, dynamic>> meetMembersRef(String meetId) {
    return meetRef(meetId).collection('members');
  }

  CollectionReference<Map<String, dynamic>> meetRequestsRef(String meetId) {
    return meetRef(meetId).collection('requests');
  }

  // =========================
  // summary / single
  // =========================

  Future<MeetSummary?> fetchMeetSummary(String meetId) async {
    final doc = await _db.collection('meets').doc(meetId).get();
    if (!doc.exists) return null;
    return MeetSummary.fromDoc(doc);
  }

  Future<MeetModel?> fetchMeet(String meetId) async {
    final doc = await _db.collection('meets').doc(meetId).get();
    if (!doc.exists) return null;
    return MeetModel.fromDoc(doc);
  }

  Future<int> fetchMeetMemberCount(String meetId) async {
    final snap = await _db
        .collection('meets')
        .doc(meetId)
        .collection('members')
        .count()
        .get();

    return snap.count ?? 0;
  }

  Future<MeetDetailPayload?> fetchMeetDetail({
    required String meetId,
    required String? myUid,
  }) async {
    final ref = meetRef(meetId);
    final membersRef = meetMembersRef(meetId);

    final meetSnap = await ref.get();
    if (!meetSnap.exists) return null;

    final meet = MeetModel.fromDoc(meetSnap);

    bool isMember = false;
    int memberCount = 0;
    String? reqStatus;

    final futures = <Future<dynamic>>[
      membersRef.count().get(),
    ];

    if (myUid != null) {
      futures.add(membersRef.doc(myUid).get());

      if (meet.needApproval && meet.authorUid != myUid) {
        futures.add(ref.collection('requests').doc(myUid).get());
      }
    }

    final results = await Future.wait(futures);

    final countSnap = results[0] as AggregateQuerySnapshot;
    memberCount = countSnap.count ?? 0;

    var cursor = 1;

    if (myUid != null) {
      final memberSnap =
      results[cursor] as DocumentSnapshot<Map<String, dynamic>>;
      isMember = memberSnap.exists;
      cursor += 1;

      if (meet.needApproval && meet.authorUid != myUid) {
        final reqSnap =
        results[cursor] as DocumentSnapshot<Map<String, dynamic>>;
        if (reqSnap.exists) {
          reqStatus = (reqSnap.data()?['status'] ?? 'pending').toString();
        }
      }
    }

    return MeetDetailPayload(
      meet: meet,
      isMember: isMember,
      memberCount: memberCount,
      myRequestStatus: reqStatus,
    );
  }

  // =========================
  // home
  // =========================

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
          final count = await fetchMeetMemberCount(meet.id);
          return (meet: meet, memberCount: count);
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
    final uid = currentUid;
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

  // =========================
  // list
  // =========================

  Query<Map<String, dynamic>> buildMeetListQuery({
    required String selectSubType,
    required String searchText,
  }) {
    Query<Map<String, dynamic>> query = _db
        .collection('meets')
        .where('status', isEqualTo: 'open');

    if (selectSubType != '전체') {
      query = query.where('category', isEqualTo: selectSubType);
    }

    final keyword = searchText.trim().toLowerCase();
    if (keyword.isNotEmpty) {
      query = query.where('searchKeywords', arrayContains: keyword);
    }

    return query.orderBy('createdAt', descending: true);
  }

  Future<List<MeetSummary>> fetchMeetSummaryPage({
    required int limit,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
  }) async {
    Query<Map<String, dynamic>> query =
    _db.collection('meets').orderBy('createdAt', descending: true);

    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    final snap = await query.limit(limit).get();
    return snap.docs.map(MeetSummary.fromDoc).toList();
  }

  // =========================
  // detail section
  // =========================

  Future<List<LightningModel>> fetchOpenLightnings(
      String meetId, {
        int limit = 5,
      }) async {
    final snap = await _db
        .collection('meets')
        .doc(meetId)
        .collection('lightnings')
        .where('status', isEqualTo: 'open')
        .orderBy('dateTime', descending: false)
        .limit(limit)
        .get();

    return snap.docs.map((d) => LightningModel.fromDoc(d)).toList();
  }

  Future<List<Map<String, dynamic>>> fetchMeetPhotoFeeds(
      String meetId, {
        int limit = 9,
      }) async {
    final snap = await _db
        .collection('feeds')
        .where('meetId', isEqualTo: meetId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();

    return snap.docs.map((d) => {'_docId': d.id, ...d.data()}).toList();
  }

  // =========================
  // create lightning
  // =========================

  Future<void> createLightning({
    required String meetId,
    required String authorUid,
    required String title,
    required String category,
    required DateTime dateTime,
    required int maxMembers,
    FeedPlace? place,
    XFile? thumbnail,
  }) async {
    final lightningRef = _db
        .collection('meets')
        .doc(meetId)
        .collection('lightnings')
        .doc();

    final lightningId = lightningRef.id;

    List<String> imageUrls = [];
    if (thumbnail != null) {
      final url = await _uploadLightningThumb(
        meetId: meetId,
        lightningId: lightningId,
        file: thumbnail,
      );
      imageUrls = [url];
    }

    final data = <String, dynamic>{
      'id': lightningId,
      'meetId': meetId,
      'authorUid': authorUid,
      'title': title.trim(),
      'category': category,
      'dateTime': Timestamp.fromDate(dateTime),
      'maxMembers': maxMembers,
      'currentMemberCount': 1,
      'userUids': [authorUid],
      'place': place?.toJson(),
      'imageUrls': imageUrls,
      'status': 'open',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    await lightningRef.set(data);
  }

  Future<String> _uploadLightningThumb({
    required String meetId,
    required String lightningId,
    required XFile file,
  }) async {
    final ref = _storage.ref().child(
      'meets/$meetId/lightnings/$lightningId/thumb.webp',
    );

    final task = await ref.putFile(File(file.path));
    if (task.state != TaskState.success) {
      throw Exception('thumbnail upload failed');
    }

    return ref.getDownloadURL();
  }

  // =========================
  // create / update meet
  // =========================

  Future<void> saveMeet({
    required String uid,
    required String title,
    required String intro,
    required String category,
    required List<MeetRegion> regions,
    required int maxMembers,
    required bool needApproval,
    String? editingMeetId,
    XFile? thumbnail,
    bool removeExistingThumbnail = false,
  }) async {
    final isEdit = editingMeetId != null;
    final meetId =
    isEdit ? editingMeetId : _db.collection('meets').doc().id;

    final meetRef = _db.collection('meets').doc(meetId);
    final searchKeywords = buildSearchKeywords(
      title: title,
      intro: intro,
      category: category,
      regions: regions,
    );

    final update = <String, dynamic>{
      'id': meetId,
      'authorUid': uid,
      'title': title.trim(),
      'intro': intro.trim(),
      'category': category,
      'regions': regions.map((e) => e.toJson()).toList(),
      'maxMembers': maxMembers,
      'needApproval': needApproval,
      'updatedAt': FieldValue.serverTimestamp(),
      'searchKeywords': searchKeywords,
    };

    if (thumbnail != null) {
      final url = await _uploadMeetThumb(meetId, uid, thumbnail);
      update['imageUrls'] = [url];
    } else if (removeExistingThumbnail) {
      await _deleteMeetThumb(meetId);
      update['imageUrls'] = [];
    }

    if (!isEdit) {
      final now = FieldValue.serverTimestamp();

      final create = <String, dynamic>{
        ...update,
        'status': 'open',
        'currentMemberCount': 1,
        'createdAt': now,
        'chatRoomId': meetId,
      };

      final memberRef = meetRef.collection('members').doc(uid);
      final chatRoomRef = _db.collection('chatRooms').doc(meetId);
      final firstMsgRef = chatRoomRef.collection('messages').doc();

      final batch = _db.batch();

      batch.set(meetRef, create);

      batch.set(memberRef, <String, dynamic>{
        'uid': uid,
        'role': 'host',
        'status': 'approved',
        'joinedAt': now,
        'createdAt': now,
        'updatedAt': now,
      });

      batch.set(chatRoomRef, <String, dynamic>{
        'type': 'group',
        'meetId': meetId,
        'title': title.trim(),
        'allowMessages': true,
        'userUids': [uid],
        'visibleUids': [uid],
        'unreadCountMap': {uid: 0},
        'activeAtMap': {uid: now},
        'lastMessageAt': now,
        'lastMessageText': '모임 채팅이 생성되었어요 🎉',
        'lastMessageType': 'system',
        'createdAt': now,
        'updatedAt': now,
      });

      batch.set(firstMsgRef, <String, dynamic>{
        'id': firstMsgRef.id,
        'type': 'system',
        'text': '모임 채팅이 생성되었어요 🎉',
        'authorUid': uid,
        'createdAt': now,
      });

      await batch.commit();
      return;
    }

    await meetRef.update(update);

    await _db.collection('chatRooms').doc(meetId).update({
      'title': title.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<String> _uploadMeetThumb(String meetId, String uid, XFile file) async {
    final ref = _storage.ref().child('meets').child(meetId).child('thumb.webp');

    final meta = SettableMetadata(
      contentType: 'image/webp',
      customMetadata: {'uploaderUid': uid, 'meetId': meetId},
    );

    await ref.putFile(File(file.path), meta);
    return ref.getDownloadURL();
  }

  Future<void> _deleteMeetThumb(String meetId) async {
    final ref = _storage.ref().child('meets').child(meetId).child('thumb.webp');
    try {
      await ref.delete();
    } catch (_) {}
  }

  List<String> buildSearchKeywords({
    required String title,
    required String intro,
    required String category,
    required List<MeetRegion> regions,
  }) {
    final regionTexts = regions.map((e) => e.fullName).toList();
    final text =
    '$title $intro $category ${regionTexts.join(" ")}'.toLowerCase();

    final words = text.split(RegExp(r'\s+'));
    final result = <String>{};

    for (final word in words) {
      if (word.isEmpty) continue;
      result.add(word);

      for (int i = 1; i <= word.length; i++) {
        result.add(word.substring(0, i));
      }
    }

    return result.toList();
  }

  // =========================
  // join / leave / request
  // =========================

  Future<void> joinMeetNow({
    required MeetModel meet,
    required String uid,
  }) async {
    final meetRef = this.meetRef(meet.id);
    final membersRef = meetMembersRef(meet.id);
    final roomRef = _db.collection('chatRooms').doc(meet.id);
    final memberRef = membersRef.doc(uid);

    await _db.runTransaction((tx) async {
      final meetSnap = await tx.get(meetRef);
      if (!meetSnap.exists) {
        throw Exception('모임이 존재하지 않아요');
      }

      final freshMeet = MeetModel.fromDoc(meetSnap);

      if (freshMeet.status != 'open') {
        throw Exception('종료된 모임이에요');
      }

      final countSnap = await membersRef.count().get();
      final currentCount = countSnap.count ?? 0;

      if (currentCount >= freshMeet.maxMembers) {
        throw Exception('정원이 마감되었습니다');
      }

      final memberSnap = await tx.get(memberRef);
      if (memberSnap.exists) {
        return;
      }

      final roomSnap = await tx.get(roomRef);
      if (!roomSnap.exists) {
        throw Exception('채팅방이 존재하지 않아요');
      }

      final roomData = roomSnap.data() as Map<String, dynamic>;

      final roomUserUids = List<String>.from(roomData['userUids'] ?? []);
      final visibleUids = List<String>.from(roomData['visibleUids'] ?? []);
      final unreadCountMap =
      Map<String, dynamic>.from(roomData['unreadCountMap'] ?? {});
      final activeAtMap =
      Map<String, dynamic>.from(roomData['activeAtMap'] ?? {});

      tx.set(memberRef, {
        'uid': uid,
        'role': 'member',
        'status': 'approved',
        'joinedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!roomUserUids.contains(uid)) roomUserUids.add(uid);
      if (!visibleUids.contains(uid)) visibleUids.add(uid);

      unreadCountMap[uid] = 0;
      activeAtMap[uid] = FieldValue.serverTimestamp();

      tx.update(roomRef, {
        'userUids': roomUserUids,
        'visibleUids': visibleUids,
        'unreadCountMap': unreadCountMap,
        'activeAtMap': activeAtMap,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      final msgRef = roomRef.collection('messages').doc();
      tx.set(msgRef, {
        'id': msgRef.id,
        'authorUid': 'system',
        'type': 'system',
        'text': '새 참가자가 들어왔어요 🎉',
        'createdAt': FieldValue.serverTimestamp(),
      });

      tx.update(roomRef, {
        'lastMessageText': '새 참가자가 들어왔어요 🎉',
        'lastMessageType': 'system',
        'lastMessageAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      tx.update(meetRef, {
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> leaveMeet({
    required MeetModel meet,
    required String uid,
    required String myNickname,
    required bool isHost,
  }) async {
    final meetRef = this.meetRef(meet.id);
    final membersRef = meetMembersRef(meet.id);
    final roomRef = _db.collection('chatRooms').doc(meet.id);
    final memberRef = membersRef.doc(uid);

    await _db.runTransaction((tx) async {
      final meetSnap = await tx.get(meetRef);
      if (!meetSnap.exists) return;

      final memberSnap = await tx.get(memberRef);
      if (!memberSnap.exists) return;

      final roomSnap = await tx.get(roomRef);

      tx.delete(memberRef);

      final countAfterLeaveSnap = await membersRef.count().get();
      final currentCount = countAfterLeaveSnap.count ?? 0;
      final nextCount = currentCount - 1;

      if (nextCount <= 0) {
        tx.delete(meetRef);
        if (roomSnap.exists) {
          tx.delete(roomRef);
        }
        return;
      }

      String? nextAuthorUid;
      if (isHost) {
        final nextMemberSnap = await membersRef
            .orderBy('joinedAt', descending: false)
            .limit(2)
            .get();

        for (final doc in nextMemberSnap.docs) {
          final nextUid = (doc.data()['uid'] ?? doc.id).toString();
          if (nextUid != uid) {
            nextAuthorUid = nextUid;
            break;
          }
        }

        if (nextAuthorUid == null) {
          final fallbackSnap = await membersRef.limit(1).get();
          if (fallbackSnap.docs.isNotEmpty) {
            nextAuthorUid = (fallbackSnap.docs.first.data()['uid'] ??
                fallbackSnap.docs.first.id)
                .toString();
          }
        }
      }

      final meetUpdates = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (isHost && nextAuthorUid != null) {
        meetUpdates['authorUid'] = nextAuthorUid;
      }

      tx.update(meetRef, meetUpdates);

      if (roomSnap.exists) {
        final roomData = roomSnap.data() as Map<String, dynamic>;

        final roomUserUids = List<String>.from(roomData['userUids'] ?? []);
        final visibleUids = List<String>.from(roomData['visibleUids'] ?? []);
        final unreadCountMap =
        Map<String, dynamic>.from(roomData['unreadCountMap'] ?? {});
        final activeAtMap =
        Map<String, dynamic>.from(roomData['activeAtMap'] ?? {});
        final chatPushOffMap =
        Map<String, dynamic>.from(roomData['chatPushOffMap'] ?? {});

        roomUserUids.remove(uid);
        visibleUids.remove(uid);
        unreadCountMap.remove(uid);
        activeAtMap.remove(uid);
        chatPushOffMap.remove(uid);

        tx.update(roomRef, {
          'userUids': roomUserUids,
          'visibleUids': visibleUids,
          'unreadCountMap': unreadCountMap,
          'activeAtMap': activeAtMap,
          'chatPushOffMap': chatPushOffMap,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        final msgRef = roomRef.collection('messages').doc();
        final text = '$myNickname님이 모임을 나갔어요';

        tx.set(msgRef, {
          'id': msgRef.id,
          'authorUid': 'system',
          'type': 'system',
          'text': text,
          'createdAt': FieldValue.serverTimestamp(),
        });

        tx.update(roomRef, {
          'lastMessageText': text,
          'lastMessageType': 'system',
          'lastMessageAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    });
  }

  Future<void> requestJoin({
    required MeetModel meet,
    required String uid,
  }) async {
    final membersRef = meetMembersRef(meet.id);
    final requestRef = meetRequestsRef(meet.id).doc(uid);

    final memberSnap = await membersRef.doc(uid).get();
    if (memberSnap.exists) return;

    final countSnap = await membersRef.count().get();
    final currentCount = countSnap.count ?? 0;
    if (currentCount >= meet.maxMembers) {
      throw Exception('정원이 마감되었어요');
    }

    final requestSnap = await requestRef.get();
    if (requestSnap.exists) return;

    await requestRef.set({
      'uid': uid,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> cancelJoinRequest({
    required String meetId,
    required String uid,
  }) async {
    await meetRequestsRef(meetId).doc(uid).delete();
  }

  Future<void> deleteMeet(String meetId) async {
    await meetRef(meetId).delete();
    await _db.collection('chatRooms').doc(meetId).delete();
  }

  Future<void> setMeetStatus({
    required String meetId,
    required String status,
  }) async {
    await meetRef(meetId).update({
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // =========================
  // helpers
  // =========================

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