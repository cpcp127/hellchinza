import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

import '../../auth/domain/user_mini.dart';
import '../domain/chat_room_model.dart';

class ChatRepo {
  ChatRepo(this._db, this._auth, this._storage);

  final FirebaseFirestore _db;
  final fb_auth.FirebaseAuth _auth;
  final FirebaseStorage _storage;

  String? get currentUid => _auth.currentUser?.uid;

  String get currentUidOrThrow {
    final uid = _auth.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      throw Exception('로그인이 필요합니다');
    }
    return uid;
  }

  Query<Map<String, dynamic>> buildChatListQuery() {
    final uid = currentUid;
    if (uid == null) {
      return _db
          .collection('chatRooms')
          .where('userUids', arrayContains: '__none__')
          .orderBy('lastMessageAt', descending: true);
    }

    return _db
        .collection('chatRooms')
        .where('visibleUids', arrayContains: uid)
        .orderBy('lastMessageAt', descending: true);
  }

  Stream<int> unreadChatCountStream() {
    final uid = currentUid;
    if (uid == null) return Stream.value(0);

    final q = _db.collection('chatRooms').where('userUids', arrayContains: uid);

    return q.snapshots().map((snap) {
      var total = 0;
      for (final doc in snap.docs) {
        final data = doc.data();
        final map = Map<String, dynamic>.from(data['unreadCountMap'] ?? {});
        final value = map[uid];
        total += value is num ? value.toInt() : 0;
      }
      return total;
    });
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> watchRoom(String roomId) {
    return _db.collection('chatRooms').doc(roomId).snapshots();
  }

  Future<Map<String, UserMini>> fetchRoomUsersMap(String roomId) async {
    final roomSnap = await _db.collection('chatRooms').doc(roomId).get();
    final data = roomSnap.data();
    if (data == null) return <String, UserMini>{};

    final uids =
        (data['userUids'] as List?)?.map((e) => e.toString()).toList() ?? [];
    if (uids.isEmpty) return <String, UserMini>{};

    final chunks = <List<String>>[];
    for (int i = 0; i < uids.length; i += 10) {
      final end = (i + 10) > uids.length ? uids.length : (i + 10);
      chunks.add(uids.sublist(i, end));
    }

    final map = <String, UserMini>{};

    for (final chunk in chunks) {
      final snap = await _db
          .collection('users')
          .where('uid', whereIn: chunk)
          .get();

      for (final d in snap.docs) {
        final mini = UserMini.fromMap(d.data(), d.id);
        map[mini.uid] = mini;
      }
    }

    return map;
  }

  Future<ChatRoomModel?> getRoomModel(String roomId) async {
    final snap = await _db.collection('chatRooms').doc(roomId).get();
    if (!snap.exists) return null;
    return ChatRoomModel.fromDoc(snap);
  }

  Future<void> enterRoom(String roomId) async {
    final uid = currentUidOrThrow;

    await _db.collection('chatRooms').doc(roomId).set({
      'unreadCountMap': {uid: 0},
      'activeAtMap': {uid: FieldValue.serverTimestamp()},
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> heartbeat(String roomId) async {
    final uid = currentUidOrThrow;
    await _db.collection('chatRooms').doc(roomId).update({
      'activeAtMap.$uid': FieldValue.serverTimestamp(),
    });
  }

  Future<void> leaveActive(String roomId) async {
    final uid = currentUid;
    if (uid == null) return;

    await _db.collection('chatRooms').doc(roomId).update({
      'activeAtMap.$uid': FieldValue.delete(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> acceptFriendRequest({
    required String roomId,
    required String requestMessageId,
    required String otherUid,
  }) async {
    final myUid = currentUidOrThrow;
    final roomRef = _db.collection('chatRooms').doc(roomId);
    final msgRef = roomRef.collection('messages').doc(requestMessageId);

    final myFriendRef =
    _db.collection('users').doc(myUid).collection('friends').doc(otherUid);
    final otherFriendRef =
    _db.collection('users').doc(otherUid).collection('friends').doc(myUid);

    await _db.runTransaction((tx) async {
      final roomSnap = await tx.get(roomRef);
      final msgSnap = await tx.get(msgRef);

      if (!roomSnap.exists) throw Exception('채팅방이 없습니다');
      if (!msgSnap.exists) throw Exception('요청 메시지가 없습니다');

      final msg = msgSnap.data() as Map<String, dynamic>;
      final status = (msg['requestStatus'] ?? 'pending').toString();
      if (status != 'pending') return;

      tx.update(roomRef, {
        'allowMessages': true,
        'friendshipStatus': 'accepted',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      tx.update(msgRef, {'requestStatus': 'accepted'});

      tx.set(myFriendRef, {
        'uid': otherUid,
        'createdAt': FieldValue.serverTimestamp(),
      });

      tx.set(otherFriendRef, {
        'uid': myUid,
        'createdAt': FieldValue.serverTimestamp(),
      });

      final sysRef = roomRef.collection('messages').doc();
      tx.set(sysRef, {
        'id': sysRef.id,
        'type': 'system',
        'authorUid': myUid,
        'text': '친구 요청을 수락했어요 🎉 이제 대화를 시작할 수 있어요.',
        'createdAt': FieldValue.serverTimestamp(),
      });

      tx.update(roomRef, {
        'lastMessageText': '친구 요청을 수락했어요 🎉',
        'lastMessageAt': FieldValue.serverTimestamp(),
        'lastMessageType': 'accept_friend_request',
      });
    });
  }

  Future<void> rejectFriendRequest({
    required String roomId,
    required String requestMessageId,
  }) async {
    final myUid = currentUidOrThrow;
    final roomRef = _db.collection('chatRooms').doc(roomId);
    final msgRef = roomRef.collection('messages').doc(requestMessageId);

    await _db.runTransaction((tx) async {
      final roomSnap = await tx.get(roomRef);
      final msgSnap = await tx.get(msgRef);

      if (!roomSnap.exists) throw Exception('채팅방이 없습니다');
      if (!msgSnap.exists) throw Exception('요청 메시지가 없습니다');

      final msg = msgSnap.data() as Map<String, dynamic>;
      final status = (msg['requestStatus'] ?? 'pending').toString();
      if (status != 'pending') return;

      tx.update(roomRef, {
        'allowMessages': false,
        'friendshipStatus': 'rejected',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      tx.update(msgRef, {'requestStatus': 'rejected'});

      final sysRef = roomRef.collection('messages').doc();
      tx.set(sysRef, {
        'id': sysRef.id,
        'type': 'system',
        'authorUid': myUid,
        'text': '친구 요청을 거절했어요.',
        'createdAt': FieldValue.serverTimestamp(),
      });

      tx.update(roomRef, {
        'lastMessageText': '친구 요청을 거절했어요.',
        'lastMessageAt': FieldValue.serverTimestamp(),
        'lastMessageType': 'reject_friend_request',
      });
    });
  }

  Future<void> sendText({
    required String roomId,
    required String text,
  }) async {
    final myUid = currentUidOrThrow;
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    final roomRef = _db.collection('chatRooms').doc(roomId);
    final msgRef = roomRef.collection('messages').doc();

    await _db.runTransaction((tx) async {
      final roomSnap = await tx.get(roomRef);
      if (!roomSnap.exists) throw Exception('채팅방이 없습니다');

      final room = roomSnap.data()!;
      final type = (room['type'] ?? 'dm').toString();
      final allow = (room['allowMessages'] ?? false) == true;
      final canSend = type == 'group' || allow;

      if (!canSend) throw Exception('친구가 되어야 메시지를 보낼 수 있어요');

      tx.set(msgRef, {
        'id': msgRef.id,
        'type': 'text',
        'authorUid': myUid,
        'text': trimmed,
        'createdAt': FieldValue.serverTimestamp(),
      });

      tx.update(roomRef, {
        'lastMessageText': trimmed,
        'lastMessageType': 'text',
        'lastMessageAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<String> createUploadingImageMessage({
    required String roomId,
    required XFile file,
  }) async {
    final myUid = currentUidOrThrow;
    final roomRef = _db.collection('chatRooms').doc(roomId);

    final roomSnap = await roomRef.get();
    if (!roomSnap.exists) throw Exception('채팅방이 없습니다');

    final room = roomSnap.data() ?? {};
    final type = (room['type'] ?? 'dm').toString();
    final allow = (room['allowMessages'] ?? false) == true;
    final canSend = type == 'group' || allow;
    if (!canSend) throw Exception('친구가 되어야 메시지를 보낼 수 있어요');

    final msgRef = roomRef.collection('messages').doc();

    await msgRef.set({
      'id': msgRef.id,
      'type': 'image',
      'authorUid': myUid,
      'imageUrl': null,
      'uploadStatus': 'uploading',
      'createdAt': FieldValue.serverTimestamp(),
    });

    await roomRef.update({
      'lastMessageText': '사진',
      'lastMessageType': 'image',
      'lastMessageAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return msgRef.id;
  }

  Future<String> uploadChatImage({
    required String roomId,
    required String msgId,
    required XFile file,
  }) async {
    final ext = file.path.toLowerCase().endsWith('.webp') ? 'webp' : 'jpg';

    final storageRef = _storage
        .ref()
        .child('chatRooms')
        .child(roomId)
        .child('images')
        .child('$msgId.$ext');

    final snap = await storageRef.putFile(File(file.path));
    return snap.ref.getDownloadURL();
  }

  Future<void> markImageUploadDone({
    required String roomId,
    required String msgId,
    required String imageUrl,
  }) async {
    await _db
        .collection('chatRooms')
        .doc(roomId)
        .collection('messages')
        .doc(msgId)
        .update({
      'imageUrl': imageUrl,
      'uploadStatus': 'done',
    });
  }

  Future<void> markImageUploadFailed({
    required String roomId,
    required String msgId,
  }) async {
    await _db
        .collection('chatRooms')
        .doc(roomId)
        .collection('messages')
        .doc(msgId)
        .update({
      'uploadStatus': 'failed',
    });
  }

  Future<void> leaveRoomAndUnfriend({
    required String roomId,
    required String otherUid,
  }) async {
    final myUid = currentUidOrThrow;
    final roomRef = _db.collection('chatRooms').doc(roomId);

    await _db.runTransaction((tx) async {
      final roomSnap = await tx.get(roomRef);
      if (!roomSnap.exists) throw Exception('채팅방이 없습니다');

      final room = roomSnap.data()!;
      final type = (room['type'] ?? 'dm').toString();

      final userUids = List<String>.from(room['userUids'] ?? const []);
      final visibleUids = List<String>.from(room['visibleUids'] ?? const []);
      final unreadCountMap =
      Map<String, dynamic>.from(room['unreadCountMap'] ?? const {});
      final activeAtMap =
      Map<String, dynamic>.from(room['activeAtMap'] ?? const {});
      final chatPushOffMap =
      Map<String, dynamic>.from(room['chatPushOffMap'] ?? const {});

      final isInUserUids = userUids.contains(myUid);
      final isInVisibleUids = visibleUids.contains(myUid);

      if (!isInUserUids && !isInVisibleUids) return;

      final updates = <String, dynamic>{
        'allowMessages': false,
        'updatedAt': FieldValue.serverTimestamp(),
        'lastMessageText': '사용자가 채팅방을 나갔습니다.',
        'lastMessageType': 'system',
        'lastMessageAt': FieldValue.serverTimestamp(),
      };

      final sysRef = roomRef.collection('messages').doc();
      tx.set(sysRef, {
        'id': sysRef.id,
        'type': 'system',
        'authorUid': 'system',
        'text': '사용자가 채팅방을 나갔습니다.',
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (type == 'dm') {
        final newVisibleUids = [...visibleUids]..remove(myUid);

        unreadCountMap.remove(myUid);
        activeAtMap.remove(myUid);
        chatPushOffMap.remove(myUid);

        updates['visibleUids'] = newVisibleUids;
        updates['unreadCountMap'] = unreadCountMap;
        updates['activeAtMap'] = activeAtMap;
        updates['chatPushOffMap'] = chatPushOffMap;
        updates['friendshipStatus'] = 'rejected';

        final myFriendRef = _db
            .collection('users')
            .doc(myUid)
            .collection('friends')
            .doc(otherUid);

        final otherFriendRef = _db
            .collection('users')
            .doc(otherUid)
            .collection('friends')
            .doc(myUid);

        tx.delete(myFriendRef);
        tx.delete(otherFriendRef);
      } else {
        final newUserUids = [...userUids]..remove(myUid);
        final newVisibleUids = [...visibleUids]..remove(myUid);

        unreadCountMap.remove(myUid);
        activeAtMap.remove(myUid);
        chatPushOffMap.remove(myUid);

        updates['userUids'] = newUserUids;
        updates['visibleUids'] = newVisibleUids;
        updates['unreadCountMap'] = unreadCountMap;
        updates['activeAtMap'] = activeAtMap;
        updates['chatPushOffMap'] = chatPushOffMap;
      }

      tx.update(roomRef, updates);
    });
  }

  Future<void> leaveGroupRoomAndMeet(String roomId) async {
    final uid = currentUidOrThrow;

    final roomRef = _db.collection('chatRooms').doc(roomId);
    final meetRef = _db.collection('meets').doc(roomId);
    final memberRef = meetRef.collection('members').doc(uid);

    await _db.runTransaction((tx) async {
      final roomSnap = await tx.get(roomRef);
      final meetSnap = await tx.get(meetRef);
      final memberSnap = await tx.get(memberRef);

      if (!roomSnap.exists || !meetSnap.exists) {
        throw Exception('데이터가 존재하지 않아요');
      }

      if (!memberSnap.exists) return;

      final roomData = roomSnap.data()!;
      final meetData = meetSnap.data()!;

      final userUids = List<String>.from(roomData['userUids'] ?? const []);
      final visibleUids = List<String>.from(roomData['visibleUids'] ?? const []);
      final unreadCountMap =
      Map<String, dynamic>.from(roomData['unreadCountMap'] ?? const {});
      final activeAtMap =
      Map<String, dynamic>.from(roomData['activeAtMap'] ?? const {});
      final chatPushOffMap =
      Map<String, dynamic>.from(roomData['chatPushOffMap'] ?? const {});

      final isHost = meetData['authorUid'] == uid;

      String nickname = '알 수 없음';
      final userRef = _db.collection('users').doc(uid);
      final userSnap = await tx.get(userRef);
      if (userSnap.exists) {
        final userData = userSnap.data();
        final rawNickname = userData?['nickname'];
        if (rawNickname is String && rawNickname.trim().isNotEmpty) {
          nickname = rawNickname.trim();
        }
      }

      tx.delete(memberRef);

      final newUserUids = [...userUids]..remove(uid);
      final newVisibleUids = [...visibleUids]..remove(uid);

      unreadCountMap.remove(uid);
      activeAtMap.remove(uid);
      chatPushOffMap.remove(uid);

      final msgRef = roomRef.collection('messages').doc();
      final systemText = '$nickname님이 모임을 나갔어요';

      tx.set(msgRef, {
        'id': msgRef.id,
        'authorUid': 'system',
        'type': 'system',
        'text': systemText,
        'createdAt': FieldValue.serverTimestamp(),
      });

      tx.update(roomRef, {
        'userUids': newUserUids,
        'visibleUids': newVisibleUids,
        'unreadCountMap': unreadCountMap,
        'activeAtMap': activeAtMap,
        'chatPushOffMap': chatPushOffMap,
        'lastMessageText': systemText,
        'lastMessageType': 'system',
        'lastMessageAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (isHost) {
        // host 변경은 아래 후처리에서도 보강하므로 여기서는 생략 가능
      }
    });

    await _fixMeetAfterLeave(roomId: roomId, leavingUid: uid);
  }

  Future<void> _fixMeetAfterLeave({
    required String roomId,
    required String leavingUid,
  }) async {
    final meetRef = _db.collection('meets').doc(roomId);
    final roomRef = _db.collection('chatRooms').doc(roomId);

    final meetSnap = await meetRef.get();
    if (!meetSnap.exists) return;

    final meetData = meetSnap.data()!;
    final wasHost = meetData['authorUid'] == leavingUid;

    final membersSnap = await meetRef
        .collection('members')
        .orderBy('joinedAt', descending: false)
        .limit(20)
        .get();

    if (membersSnap.docs.isEmpty) {
      await roomRef.delete();
      await meetRef.delete();
      return;
    }

    if (wasHost) {
      String? nextHostUid;

      for (final doc in membersSnap.docs) {
        final data = doc.data();
        final nextUid = (data['uid'] ?? doc.id).toString();
        if (nextUid != leavingUid) {
          nextHostUid = nextUid;
          break;
        }
      }

      if (nextHostUid != null) {
        await meetRef.update({
          'authorUid': nextHostUid,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        await meetRef.collection('members').doc(nextHostUid).set({
          'role': 'host',
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    }
  }

  Future<bool> getRoomPushEnabled({
    required String roomId,
    required String uid,
  }) async {
    final doc = await _db.collection('chatRooms').doc(roomId).get();
    final data = doc.data() ?? {};
    final map = (data['chatPushOffMap'] as Map<String, dynamic>?) ?? {};
    final value = map[uid];
    return value != false;
  }

  Future<void> setRoomPushEnabled({
    required String roomId,
    required String uid,
    required bool enabled,
  }) async {
    await _db.collection('chatRooms').doc(roomId).set({
      'chatPushOffMap': {uid: enabled ? true : false},
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> toggleRoomPush({
    required String roomId,
    required String uid,
  }) async {
    final enabled = await getRoomPushEnabled(roomId: roomId, uid: uid);
    await setRoomPushEnabled(roomId: roomId, uid: uid, enabled: !enabled);
  }

  DateTime? createdAtFrom(Map<String, dynamic> data) {
    final ts = data['createdAt'];
    if (ts is Timestamp) return ts.toDate();
    if (ts is DateTime) return ts;
    return null;
  }

  bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String formatDayKorean(DateTime d) {
    const week = ['월', '화', '수', '목', '금', '토', '일'];
    final w = week[(d.weekday - 1).clamp(0, 6)];
    return '${d.year}. ${d.month}. ${d.day} ($w)';
  }

  Query<Map<String, dynamic>> buildMessagesQuery(String roomId) {
    return _db
        .collection('chatRooms')
        .doc(roomId)
        .collection('messages')
        .orderBy('createdAt', descending: true);
  }

  Future<UserMini?> fetchOtherUser(String roomId, String myUid) async {
    final roomSnap = await _db.collection('chatRooms').doc(roomId).get();
    final data = roomSnap.data();
    if (data == null) return null;

    final members = List<String>.from(data['userUids'] ?? const []);
    final otherUid = members.firstWhere((u) => u != myUid, orElse: () => '');
    if (otherUid.isEmpty) return null;

    final userSnap = await _db.collection('users').doc(otherUid).get();
    if (!userSnap.exists || userSnap.data() == null) return null;

    return UserMini.fromMap(userSnap.data()!, otherUid);
  }
}