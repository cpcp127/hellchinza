import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:hellchinza/meet/meet_create/meet_create_view.dart';

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

  Future<void> init() async {
    final myUid = _auth.currentUser?.uid;

    state = MeetDetailState(
      isLoading: true,
      errorMessage: null,
      meet: null,
      myUid: myUid,
      myRequestStatus: null,
    );

    try {
      final meetSnap = await _meetRef.get();
      if (!meetSnap.exists) {
        state = state.copyWith(isLoading: false, errorMessage: '모임이 없어요');
        return;
      }

      final meet = MeetModel.fromDoc(meetSnap);

      String? reqStatus;

      // ✅ 남의 모임 + needApproval인 경우만 요청 상태 확인
      if (myUid != null && meet.needApproval == true && meet.authorUid != myUid) {
        final reqSnap = await _meetRef.collection('requests').doc(myUid).get();
        if (reqSnap.exists) {
          reqStatus = (reqSnap.data()?['status'] ?? 'pending').toString();
        }
      }

      state = state.copyWith(
        isLoading: false,
        meet: meet,
        myUid: myUid,
        myRequestStatus: reqStatus,
        clearError: true,
      );
    } catch (_) {
      state = state.copyWith(isLoading: false, errorMessage: '불러오기 실패');
    }
  }


  /// ✅ 남의 모임: 참가(또는 요청)
  Future<void> joinNow() async {
    final meet = state.meet;
    final uid = state.myUid;
    if (meet == null || uid == null) throw Exception('로그인이 필요해요');
    if (state.isOwner) return;
    if (state.isMember) return;

    if (meet.status != 'open') throw Exception('종료된 모임이에요');
    if (state.isFull) throw Exception('정원이 마감되었습니다');
    if (meet.needApproval == true) {
      throw Exception('승인이 필요한 모임이에요'); // 안전장치
    }

    await _db.runTransaction((tx) async {
      final snap = await tx.get(_meetRef);
      final data = snap.data()!;
      final current = (data['currentMemberCount'] ?? 0) as int;
      final max = (data['maxMembers'] ?? 0) as int;
      final memberUids = List<String>.from(data['memberUids'] ?? []);

      if (memberUids.contains(uid)) return;
      if (current >= max) throw Exception('정원이 마감되었습니다');

      memberUids.add(uid);

      tx.update(_meetRef, {
        'memberUids': memberUids,
        'currentMemberCount': current + 1,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });

    await init();
  }

  /// ✅ 남의 모임: 나가기
  Future<void> leaveMeet() async {
    final meet = state.meet;
    final uid = state.myUid;
    if (meet == null || uid == null) throw Exception('로그인이 필요해요');

    if (state.isOwner) throw Exception('호스트는 나갈 수 없어요');
    if (!state.isMember) return;

    await _db.runTransaction((tx) async {
      final snap = await tx.get(_meetRef);
      final data = snap.data()!;
      final current = (data['currentMemberCount'] ?? 0) as int;
      final memberUids = List<String>.from(data['memberUids'] ?? []);

      if (!memberUids.contains(uid)) return;

      memberUids.remove(uid);

      tx.update(_meetRef, {
        'memberUids': memberUids,
        'currentMemberCount': (current - 1).clamp(0, 999999),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });

    await init();
  }


  Future<void> requestJoin() async {
    final meet = state.meet;
    final uid = state.myUid;
    if (meet == null || uid == null) throw Exception('로그인이 필요해요');
    if (state.isOwner || state.isMember) return;
    if (meet.needApproval != true) return;
    if (state.isFull) throw Exception('정원이 마감되었어요');
    if (meet.status != 'open') throw Exception('종료된 모임이에요');

    final ref = _meetRef.collection('requests').doc(uid);

    // 이미 요청중이면 리턴
    final snap = await ref.get();
    if (snap.exists) return;

    await ref.set({
      'uid': uid,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });

    await init();
  }

  Future<void> cancelRequest() async {
    final meet = state.meet;
    final uid = state.myUid;
    if (meet == null || uid == null) throw Exception('로그인이 필요해요');
    if (meet.needApproval != true) return;

    await _meetRef.collection('requests').doc(uid).delete();
    await init();
  }


  /// ✅ 내 모임: 삭제 (삭제 전 confirm은 View에서)
  Future<void> deleteMeet() async {
    if (!state.isOwner) return;
    await _meetRef.delete();
  }

  /// ✅ 내 모임: 상태 변경(open/closed 등) 필요하면
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
    required MeetDetailController controller,required BuildContext context
  }) async {
    final meet = state.meet;
    if (meet == null) return;

    try {
      // 1) 종료/마감 처리
      if (meet.status != 'open') {
        SnackbarService.show(type: AppSnackType.error, message: '종료된 모임이에요');
        return;
      }

      // 2) 내가 호스트면 (여긴 네가 원하는 동작으로)
      if (state.isOwner) {
        final updated = await   Navigator.push(
          context,
          CupertinoPageRoute(
            fullscreenDialog: true,
            builder: (context) {
              return MeetCreateStepperView(meetId: state.meet!.id);
            },
          ),
        );

        if (updated == true) controller.init();
        return;
      }

      // 3) 이미 참가한 상태면 -> 참가 취소
      if (state.isMember) {
        await controller.leaveMeet();
        SnackbarService.show(type: AppSnackType.success, message: '참가를 취소했어요');
        return;
      }

      // 4) 승인 필요 모임이면 -> 요청/요청취소
      if (meet.needApproval == true) {
        if (state.isRequested) {
          await controller.cancelRequest();   // ✅ 이미 있음
          SnackbarService.show(type: AppSnackType.success, message: '요청을 취소했어요');
        } else {
          if (state.isFull) {
            SnackbarService.show(type: AppSnackType.error, message: '정원이 마감되었습니다');
            return;
          }
          await controller.requestJoin();     // ✅ 이미 있음
          SnackbarService.show(type: AppSnackType.success, message: '참가 요청을 보냈어요');
        }
        return;
      }

      // 5) 승인 필요 없는 모임 -> 즉시 참가
      await controller.joinNow();
      SnackbarService.show(type: AppSnackType.success, message: '모임에 참가했어요');
    } catch (e) {
      SnackbarService.show(type: AppSnackType.error, message: e.toString());
    }
  }

}
