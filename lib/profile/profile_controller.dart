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

  Future<void> sendFriendRequest({
    required String targetUid,
    required String message,
  }) async {
    final db = FirebaseFirestore.instance;
    final myUid = FirebaseAuth.instance.currentUser!.uid;

    final a = myUid.compareTo(targetUid) < 0 ? myUid : targetUid;
    final b = myUid.compareTo(targetUid) < 0 ? targetUid : myUid;
    final roomId = 'dm_${a}_$b';

    final roomRef = db.collection('chatRooms').doc(roomId);
    final msgRef = roomRef.collection('messages').doc();

    await db.runTransaction((tx) async {
      // ✅ READ 먼저
      final roomSnap = await tx.get(roomRef);

      if (roomSnap.exists) {
        final data = roomSnap.data()!;
        final status = (data['status'] ?? 'pending').toString();

        // 이미 친구(active)면 굳이 요청메시지 다시 만들 필요 없음(원하면 채팅방으로 이동)
        if (status == 'active') {
          throw Exception('이미 친구예요');
        }

        // 이미 pending이면 중복 요청 막기 (원하면 덮어쓰기 정책도 가능)
        if (status == 'pending') {
          throw Exception('이미 친구 요청을 보냈거나 받은 상태예요');
        }
      }

      // ✅ WRITE
      // 방이 없으면 생성
      if (!roomSnap.exists) {
        tx.set(roomRef, {
          'id': roomId,
          'userUids': [myUid, targetUid],
          'type': 'dm',
          'status': 'pending',
          'requestFromUid': myUid,
          'requestMessageId': msgRef.id,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'lastMessage': message,
          'lastMessageType': 'friend_request',
          'lastMessageAt': FieldValue.serverTimestamp(),
        });
      } else {
        // 방이 있어도 pending으로 갱신(거절 후 재요청 같은 케이스)
        tx.update(roomRef, {
          'status': 'pending',
          'requestFromUid': myUid,
          'requestMessageId': msgRef.id,
          'updatedAt': FieldValue.serverTimestamp(),
          'lastMessage': message,
          'lastMessageType': 'friend_request',
          'lastMessageAt': FieldValue.serverTimestamp(),
        });
      }

      // friend_request 메시지 생성
      tx.set(msgRef, {
        'id': msgRef.id,
        'type': 'friend_request',
        'authorUid': myUid,
        'text': message,
        'requestStatus': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }


}
