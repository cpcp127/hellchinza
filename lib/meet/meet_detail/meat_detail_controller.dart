import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:hellchinza/auth/domain/user_model.dart';
import 'package:hellchinza/meet/meet_create/meet_create_view.dart';
import 'package:hellchinza/meet/meet_list/meet_list_controller.dart';

import '../../auth/providers/user_provider.dart';
import '../../services/snackbar_service.dart';
import '../domain/meet_model.dart';
import 'meat_detail_state.dart';

final meetDetailControllerProvider = StateNotifierProvider.autoDispose
    .family<MeetDetailController, MeetDetailState, String>((ref, meetId) {
  return MeetDetailController(ref, meetId)..init();
});

class MeetDetailController extends StateNotifier<MeetDetailState> {
  MeetDetailController(this.ref, this.meetId)
      : super(const MeetDetailState.initial());

  final Ref ref;
  final String meetId;

  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  DocumentReference<Map<String, dynamic>> get _meetRef =>
      _db.collection('meets').doc(meetId);

  CollectionReference<Map<String, dynamic>> get _membersRef =>
      _meetRef.collection('members');

  Future<void> init() async {
    final myUid = _auth.currentUser?.uid;

    state = MeetDetailState(
      isLoading: true,
      errorMessage: null,
      meet: null,
      myUid: myUid,
      myRequestStatus: null,
      isMember: false,
      memberCount: 0,
    );

    try {
      final meetSnap = await _meetRef.get();
      if (!meetSnap.exists) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: '모임이 없어요',
        );
        return;
      }

      final meet = MeetModel.fromDoc(meetSnap);

      bool isMember = false;
      int memberCount = 0;
      String? reqStatus;

      final futures = <Future<dynamic>>[
        _membersRef.count().get(),
      ];

      if (myUid != null) {
        futures.add(_membersRef.doc(myUid).get());

        if (meet.needApproval && meet.authorUid != myUid) {
          futures.add(_meetRef.collection('requests').doc(myUid).get());
        }
      }

      final results = await Future.wait(futures);

      final countSnap = results[0] as AggregateQuerySnapshot;
      memberCount = countSnap.count ?? 0;

      var cursor = 1;

      if (myUid != null) {
        final memberSnap = results[cursor] as DocumentSnapshot<Map<String, dynamic>>;
        isMember = memberSnap.exists;
        cursor += 1;

        if (meet.needApproval && meet.authorUid != myUid) {
          final reqSnap = results[cursor] as DocumentSnapshot<Map<String, dynamic>>;
          if (reqSnap.exists) {
            reqStatus = (reqSnap.data()?['status'] ?? 'pending').toString();
          }
        }
      }

      state = state.copyWith(
        isLoading: false,
        meet: meet,
        myUid: myUid,
        isMember: isMember,
        memberCount: memberCount,
        myRequestStatus: reqStatus,
        clearError: true,
      );
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: '불러오기 실패',
      );
    }
  }

  Future<void> joinNow() async {
    final meet = state.meet;
    final uid = state.myUid;

    if (meet == null || uid == null) {
      throw Exception('로그인이 필요해요');
    }
    if (state.isOwner) return;
    if (state.isMember) return;

    if (meet.status != 'open') {
      throw Exception('종료된 모임이에요');
    }
    if (state.isFull) {
      throw Exception('정원이 마감되었습니다');
    }
    if (meet.needApproval) {
      throw Exception('승인이 필요한 모임이에요');
    }

    final roomRef = _db.collection('chatRooms').doc(meet.id);
    final memberRef = _membersRef.doc(uid);

    await _db.runTransaction((tx) async {
      final meetSnap = await tx.get(_meetRef);
      if (!meetSnap.exists) {
        throw Exception('모임이 존재하지 않아요');
      }

      final freshMeet = MeetModel.fromDoc(meetSnap);

      if (freshMeet.status != 'open') {
        throw Exception('종료된 모임이에요');
      }

      final countSnap = await _membersRef.count().get();
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

      tx.update(_meetRef, {
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });

    await init();
    ref.read(meetListControllerProvider.notifier).refresh();
  }

  Future<void> leaveMeet() async {
    final meet = state.meet;
    final uid = state.myUid;
    final myNickname = ref.read(myUserModelProvider).nickname;

    if (meet == null || uid == null) {
      throw Exception('로그인이 필요해요');
    }

    final isHost = state.isOwner;
    final roomRef = _db.collection('chatRooms').doc(meet.id);
    final memberRef = _membersRef.doc(uid);

    await _db.runTransaction((tx) async {
      final meetSnap = await tx.get(_meetRef);
      if (!meetSnap.exists) return;

      final memberSnap = await tx.get(memberRef);
      if (!memberSnap.exists) return;

      DocumentSnapshot<Map<String, dynamic>>? roomSnap;
      roomSnap = await tx.get(roomRef);

      tx.delete(memberRef);

      final countAfterLeaveSnap = await _membersRef.count().get();
      final currentCount = countAfterLeaveSnap.count ?? 0;
      final nextCount = currentCount - 1;

      if (nextCount <= 0) {
        tx.delete(_meetRef);

        if (roomSnap.exists) {
          tx.delete(roomRef);
        }
        return;
      }

      String? nextAuthorUid;
      if (isHost) {
        final nextMemberSnap = await _membersRef
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
          final fallbackSnap = await _membersRef.limit(1).get();
          if (fallbackSnap.docs.isNotEmpty) {
            nextAuthorUid =
                (fallbackSnap.docs.first.data()['uid'] ?? fallbackSnap.docs.first.id)
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

      tx.update(_meetRef, meetUpdates);

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

    await init();
    ref.read(meetListControllerProvider.notifier).refresh();
  }

  Future<void> requestJoin() async {
    final meet = state.meet;
    final uid = state.myUid;

    if (meet == null || uid == null) {
      throw Exception('로그인이 필요해요');
    }
    if (state.isOwner || state.isMember) return;
    if (!meet.needApproval) return;
    if (state.isFull) {
      throw Exception('정원이 마감되었어요');
    }
    if (meet.status != 'open') {
      throw Exception('종료된 모임이에요');
    }

    final requestRef = _meetRef.collection('requests').doc(uid);

    final memberSnap = await _membersRef.doc(uid).get();
    if (memberSnap.exists) return;

    final countSnap = await _membersRef.count().get();
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

    await init();
  }

  Future<void> cancelRequest() async {
    final meet = state.meet;
    final uid = state.myUid;

    if (meet == null || uid == null) {
      throw Exception('로그인이 필요해요');
    }
    if (!meet.needApproval) return;

    await _meetRef.collection('requests').doc(uid).delete();
    await init();
  }

  Future<void> deleteMeet() async {
    if (!state.isOwner) return;

    await _meetRef.delete();
    await _db.collection('chatRooms').doc(state.meet!.id).delete();
  }

  Future<void> setStatus(String status) async {
    if (!state.isOwner) return;

    await _meetRef.update({
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await init();
  }

  Future<void> onTapMeetPrimaryButton({
    required MeetDetailState state,
    required MeetDetailController controller,
    required BuildContext context,
  }) async {
    final meet = state.meet;
    if (meet == null) return;

    try {
      if (meet.status != 'open') {
        SnackbarService.show(
          type: AppSnackType.error,
          message: '종료된 모임이에요',
        );
        return;
      }

      if (state.isOwner) {
        final updated = await Navigator.push(
          context,
          CupertinoPageRoute(
            fullscreenDialog: true,
            builder: (context) {
              return MeetCreateStepperView(meetId: state.meet!.id);
            },
          ),
        );

        if (updated == true) {
          await controller.init();
        }
        return;
      }

      if (state.isMember) {
        await controller.leaveMeet();
        SnackbarService.show(
          type: AppSnackType.success,
          message: '참가를 취소했어요',
        );
        return;
      }

      if (meet.needApproval) {
        if (state.isRequested) {
          await controller.cancelRequest();
          SnackbarService.show(
            type: AppSnackType.success,
            message: '요청을 취소했어요',
          );
        } else {
          if (state.isFull) {
            SnackbarService.show(
              type: AppSnackType.error,
              message: '정원이 마감되었습니다',
            );
            return;
          }
          await controller.requestJoin();
          SnackbarService.show(
            type: AppSnackType.success,
            message: '참가 요청을 보냈어요',
          );
        }
        return;
      }

      await controller.joinNow();
      SnackbarService.show(
        type: AppSnackType.success,
        message: '모임에 참가했어요',
      );
    } catch (e) {
      SnackbarService.show(
        type: AppSnackType.error,
        message: e.toString(),
      );
    }
  }
}