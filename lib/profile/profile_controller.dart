import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:hellchinza/profile/profile_state.dart';

final profileControllerProvider = StateNotifierProvider.autoDispose
    .family<ProfileController, ProfileState, String>((ref, uid) {
  return ProfileController(ref, uid)..init();
});

class ProfileController extends StateNotifier<ProfileState> {
  ProfileController(this.ref, this.targetUid)
      : super(ProfileState.initial(targetUid));

  final Ref ref;
  final String targetUid;

  final _db = FirebaseFirestore.instance;

  String _pairId(String a, String b) {
    final list = [a, b]..sort();
    return '${list[0]}_${list[1]}';
  }

  Future<void> init() async {
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    if (myUid == null) {
      state = state.copyWith(isLoading: false, myUid: null, relation: FriendRelation.none);
      return;
    }

    // ✅ 관계 상태 계산 (friends or request pending)
    // - friends: users/{myUid}/friends/{targetUid} 존재 여부
    // - request: friend_requests/{pairId} status 체크
    final pairId = _pairId(myUid, targetUid);
    final myFriendRef = _db.collection('users').doc(myUid).collection('friends').doc(targetUid);
    final reqRef = _db.collection('friend_requests').doc(pairId);

    try {
      final friendSnap = await myFriendRef.get();
      if (friendSnap.exists) {
        state = state.copyWith(
          isLoading: false,
          myUid: myUid,
          relation: FriendRelation.friends,
        );
        return;
      }

      final reqSnap = await reqRef.get();
      if (reqSnap.exists) {
        final data = reqSnap.data()!;
        final status = (data['status'] ?? 'pending').toString();
        final fromUid = (data['fromUid'] ?? '').toString();
        final toUid = (data['toUid'] ?? '').toString();

        if (status == 'pending') {
          if (fromUid == myUid && toUid == targetUid) {
            state = state.copyWith(
              isLoading: false,
              myUid: myUid,
              relation: FriendRelation.pendingOut,
            );
            return;
          }
          if (fromUid == targetUid && toUid == myUid) {
            state = state.copyWith(
              isLoading: false,
              myUid: myUid,
              relation: FriendRelation.pendingIn,
            );
            return;
          }
        }
      }

      state = state.copyWith(
        isLoading: false,
        myUid: myUid,
        relation: FriendRelation.none,
      );
    } catch (_) {
      // 실패해도 버튼은 기본 none으로
      state = state.copyWith(isLoading: false, myUid: myUid, relation: FriendRelation.none);
    }
  }

  Future<String> sendFriendRequest({
    required String otherUid,
    required String requestText,
  }) async {
    final myUid = FirebaseAuth.instance.currentUser!.uid;

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
        // 방 생성
        tx.set(roomRef, {
          'type': 'dm',
          'dmKey': key,
          'userUids': [myUid, otherUid],'visibleUids': [myUid, otherUid],
          'allowMessages': false,
          'friendshipStatus': 'pending',
          'unreadCountMap': {myUid: 0, otherUid: 1}, // 상대에게 1개
          'activeAtMap': {},
          'lastMessageText': requestText.trim(),
          'lastMessageAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        final room = roomSnap.data()!;
        final status = (room['friendshipStatus'] ?? '').toString();
        if (status == 'accepted') {
          // 이미 친구면 요청 안 만들고 그냥 방만 사용
          return;
        }
        // pending이면 중복 요청 메시지 만들지 않게 하고 싶으면 여기서 return 가능
      }

      // friend_request 메시지
      tx.set(msgRef, {
        'id': msgRef.id,
        'type': 'friend_request',
        'authorUid': myUid,
        'text': requestText.trim(),
        'requestStatus': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // lastMessageText 갱신(채팅리스트에서 "수락대기"로 보이게)
      tx.set(roomRef, {
        'lastMessageText': requestText.trim(),
        'lastMessageAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'allowMessages': false,
        'friendshipStatus': 'pending',
      }, SetOptions(merge: true));
    });

    return key; // roomId
  }

  Future<void> blockUser({required String targetUid}) async {
    final myUid = FirebaseAuth.instance.currentUser!.uid;
    final myBlockRef =
    _db.collection('users').doc(myUid).collection('blocks').doc(targetUid);

    final myFriendRef =
    _db.collection('users').doc(myUid).collection('friends').doc(targetUid);
    final otherFriendRef =
    _db.collection('users').doc(targetUid).collection('friends').doc(myUid);

    await _db.runTransaction((tx) async {
      // READ 먼저 (필요하면)
      final blockSnap = await tx.get(myBlockRef);

      if (!blockSnap.exists) {
        tx.set(myBlockRef, {
          'uid': targetUid,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      // ✅ 친구도 끊기 (존재하면 삭제)
      tx.delete(myFriendRef);
      tx.delete(otherFriendRef);
    });
  }

}
