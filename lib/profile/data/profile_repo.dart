import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:hellchinza/auth/domain/user_model.dart';
import 'package:hellchinza/meet/domain/meet_model.dart';
import 'package:hellchinza/services/storage_upload_service.dart';

import '../profile_state.dart';

class ProfileRepo {
  ProfileRepo({
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

  String _pairId(String a, String b) {
    final list = [a, b]..sort();
    return '${list[0]}_${list[1]}';
  }

  Future<UserModel?> fetchUserByUid(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    return UserModel.fromFirestore(doc.data()!);
  }

  Future<bool> isFriend(String targetUid) async {
    final myUid = currentUid;
    if (myUid == null) return false;
    if (myUid == targetUid) return true;

    final doc = await _db
        .collection('users')
        .doc(myUid)
        .collection('friends')
        .doc(targetUid)
        .get();

    return doc.exists;
  }

  Future<int> fetchFriendCount(String uid) async {
    final snapshot = await _db
        .collection('users')
        .doc(uid)
        .collection('friends')
        .count()
        .get();

    return snapshot.count ?? 0;
  }

  Future<List<MeetModel>> fetchHostedMeetPreview(String uid) async {
    final snap = await _db
        .collection('meets')
        .where('authorUid', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .limit(3)
        .get();

    return snap.docs.map((d) => MeetModel.fromDoc(d)).toList();
  }

  Future<List<MeetModel>> fetchHostedMeetAll(String uid) async {
    final snap = await _db
        .collection('meets')
        .where('status', isEqualTo: 'open')
        .where('authorUid', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .get();

    return snap.docs.map((d) => MeetModel.fromDoc(d)).toList();
  }

  Future<List<MeetModel>> fetchJoinedMeetPreview(String uid) async {
    final memberSnap = await _db
        .collectionGroup('members')
        .where('uid', isEqualTo: uid)
        .get();

    final meetRefs = memberSnap.docs
        .map((doc) => doc.reference.parent.parent)
        .whereType<DocumentReference<Map<String, dynamic>>>()
        .toList();

    final meetSnaps = await Future.wait(meetRefs.map((ref) => ref.get()));

    final meets = meetSnaps
        .where((doc) => doc.exists)
        .map((doc) => MeetModel.fromDoc(doc))
        .where((meet) => meet.authorUid != uid)
        .toList()
      ..sort((a, b) {
        final aTime = a.createdAt ?? DateTime(1970);
        final bTime = b.createdAt ?? DateTime(1970);
        return aTime.compareTo(bTime);
      });

    return meets.take(3).toList();
  }

  Future<List<MeetModel>> fetchJoinedMeetAll(String uid) async {
    final memberSnap = await _db
        .collectionGroup('members')
        .where('uid', isEqualTo: uid)
        .get();

    if (memberSnap.docs.isEmpty) return [];

    final meetRefs = memberSnap.docs
        .map((doc) => doc.reference.parent.parent)
        .whereType<DocumentReference<Map<String, dynamic>>>()
        .toList();

    final meetSnaps = await Future.wait(meetRefs.map((ref) => ref.get()));

    final meets = meetSnaps
        .where((doc) => doc.exists)
        .map((doc) => MeetModel.fromDoc(doc))
        .where((meet) => meet.status == 'open')
        .where((meet) => meet.authorUid != uid)
        .toList()
      ..sort((a, b) {
        final aTime = a.createdAt ?? DateTime(1970);
        final bTime = b.createdAt ?? DateTime(1970);
        return aTime.compareTo(bTime);
      });

    return meets;
  }

  Future<FriendRelation> fetchRelation(String targetUid) async {
    final myUid = currentUid;
    if (myUid == null) return FriendRelation.none;
    if (myUid == targetUid) return FriendRelation.none;

    final pairId = _pairId(myUid, targetUid);
    final myFriendRef = _db
        .collection('users')
        .doc(myUid)
        .collection('friends')
        .doc(targetUid);
    final reqRef = _db.collection('friend_requests').doc(pairId);

    final friendSnap = await myFriendRef.get();
    if (friendSnap.exists) {
      return FriendRelation.friends;
    }

    final reqSnap = await reqRef.get();
    if (!reqSnap.exists) return FriendRelation.none;

    final data = reqSnap.data()!;
    final status = (data['status'] ?? 'pending').toString();
    final fromUid = (data['fromUid'] ?? '').toString();
    final toUid = (data['toUid'] ?? '').toString();

    if (status == 'pending') {
      if (fromUid == myUid && toUid == targetUid) {
        return FriendRelation.pendingOut;
      }
      if (fromUid == targetUid && toUid == myUid) {
        return FriendRelation.pendingIn;
      }
    }

    return FriendRelation.none;
  }

  Future<String> sendFriendRequest({
    required String otherUid,
    required String requestText,
  }) async {
    final myUid = _auth.currentUser!.uid;

    String dmKey(String a, String b) {
      final x = [a, b]..sort();
      return '${x[0]}_${x[1]}';
    }

    final key = dmKey(myUid, otherUid);
    final roomRef = _db.collection('chatRooms').doc(key);
    final msgRef = roomRef.collection('messages').doc();

    await _db.runTransaction((tx) async {
      final roomSnap = await tx.get(roomRef);

      if (!roomSnap.exists) {
        tx.set(roomRef, {
          'type': 'dm',
          'dmKey': key,
          'userUids': [myUid, otherUid],
          'visibleUids': [myUid, otherUid],
          'allowMessages': false,
          'friendshipStatus': 'pending',
          'unreadCountMap': {myUid: 0, otherUid: 1},
          'activeAtMap': {},
          'lastMessageText': requestText.trim(),
          'lastMessageAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        final room = roomSnap.data()!;
        final status = (room['friendshipStatus'] ?? '').toString();
        if (status == 'accepted') {
          return;
        }
      }

      tx.set(msgRef, {
        'id': msgRef.id,
        'type': 'friend_request',
        'authorUid': myUid,
        'text': requestText.trim(),
        'requestStatus': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      tx.set(
        roomRef,
        {
          'lastMessageText': requestText.trim(),
          'lastMessageAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'allowMessages': false,
          'friendshipStatus': 'pending',
        },
        SetOptions(merge: true),
      );
    });

    return key;
  }

  Future<void> blockUser({required String targetUid}) async {
    final myUid = _auth.currentUser!.uid;
    final myBlockRef = _db
        .collection('users')
        .doc(myUid)
        .collection('blocks')
        .doc(targetUid);

    final myFriendRef = _db
        .collection('users')
        .doc(myUid)
        .collection('friends')
        .doc(targetUid);
    final otherFriendRef = _db
        .collection('users')
        .doc(targetUid)
        .collection('friends')
        .doc(myUid);

    await _db.runTransaction((tx) async {
      final blockSnap = await tx.get(myBlockRef);

      if (!blockSnap.exists) {
        tx.set(myBlockRef, {
          'uid': targetUid,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      tx.delete(myFriendRef);
      tx.delete(otherFriendRef);
    });
  }

  Future<void> saveProfile({
    required XFile? selectedImage,
    required String nickname,
    required String description,
    required List<String> category,
    required bool deletePhoto,
  }) async {
    final uid = _auth.currentUser!.uid;
    final userRef = _db.collection('users').doc(uid);
    final snap = await userRef.get();
    final prevPath = snap.data()?['photoPath'] as String?;

    UploadResult? uploaded;
    if (selectedImage != null) {
      uploaded = await const StorageUploadService().uploadProfileImage(
        uid: uid,
        file: selectedImage,
      );
    }

    final data = <String, dynamic>{
      'nickname': nickname,
      'description': description,
      'category': category,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (deletePhoto) {
      data['photoUrl'] = null;
      data['photoPath'] = null;
    }

    if (uploaded != null) {
      data['photoUrl'] = uploaded.url;
      data['photoPath'] = uploaded.path;
    }

    await userRef.set(data, SetOptions(merge: true));

    final shouldDeletePrev = (uploaded != null) || deletePhoto;
    if (shouldDeletePrev && prevPath != null && prevPath.isNotEmpty) {
      try {
        await _storage.ref(prevPath).delete();
      } catch (_) {}
    }
  }
}