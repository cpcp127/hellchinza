import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../auth/providers/user_provider.dart';
import '../../../services/snackbar_service.dart';
import '../data/meet_repo.dart';
import '../meet_create/meet_create_view.dart';
import '../providers/meet_provider.dart';
import 'meat_detail_state.dart';

class MeetDetailController extends StateNotifier<MeetDetailState> {
  MeetDetailController(this.ref, this._repo, this.meetId)
    : super(const MeetDetailState.initial());

  final Ref ref;
  final MeetRepo _repo;
  final String meetId;

  Future<void> init() async {
    final myUid = _repo.currentUid;

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
      final payload = await _repo.fetchMeetDetail(meetId: meetId, myUid: myUid);

      if (payload == null) {
        state = state.copyWith(isLoading: false, errorMessage: '모임이 없어요');
        return;
      }

      state = state.copyWith(
        isLoading: false,
        meet: payload.meet,
        myUid: myUid,
        isMember: payload.isMember,
        memberCount: payload.memberCount,
        myRequestStatus: payload.myRequestStatus,
        clearError: true,
      );
    } catch (_) {
      state = state.copyWith(isLoading: false, errorMessage: '불러오기 실패');
    }
  }

  Future<void> joinNow() async {
    final meet = state.meet;
    final uid = state.myUid;

    if (meet == null || uid == null) {
      throw Exception('로그인이 필요해요');
    }
    if (state.isOwner || state.isMember) return;

    if (meet.status != 'open') {
      throw Exception('종료된 모임이에요');
    }
    if (state.isFull) {
      throw Exception('정원이 마감되었습니다');
    }
    if (meet.needApproval) {
      throw Exception('승인이 필요한 모임이에요');
    }

    await _repo.joinMeetNow(meet: meet, uid: uid);

    await init();
    _refreshMeetList();
  }

  Future<void> requestJoin() async {
    final meet = state.meet;
    final uid = state.myUid;

    if (meet == null || uid == null) {
      throw Exception('로그인이 필요해요');
    }
    if (!state.canRequest) return;

    await _repo.requestJoin(meet: meet, uid: uid);

    await init();
  }

  Future<void> cancelJoinRequest() async {
    final uid = state.myUid;
    if (uid == null) {
      throw Exception('로그인이 필요해요');
    }

    await _repo.cancelJoinRequest(meetId: meetId, uid: uid);

    await init();
  }

  Future<void> leaveMeet() async {
    final meet = state.meet;
    final uid = state.myUid;
    final myUser = ref.read(myUserModelProvider);

    if (meet == null || uid == null) {
      throw Exception('로그인이 필요해요');
    }

    await _repo.leaveMeet(
      meet: meet,
      uid: uid,
      myNickname: myUser.nickname,
      isHost: state.isOwner,
    );

    await init();
    _refreshMeetList();
  }

  Future<void> deleteMeet() async {
    final meet = state.meet;
    if (meet == null) return;

    await _repo.deleteMeet(meet.id);
    _refreshMeetList();
  }

  Future<void> closeMeet() async {
    final meet = state.meet;
    if (meet == null) return;

    await _repo.setMeetStatus(meetId: meet.id, status: 'closed');

    await init();
    _refreshMeetList();
  }

  Future<void> reopenMeet() async {
    final meet = state.meet;
    if (meet == null) return;

    await _repo.setMeetStatus(meetId: meet.id, status: 'open');

    await init();
    _refreshMeetList();
  }

  Future<void> onTapMeetPrimaryButton(BuildContext context) async {
    final meet = state.meet;
    if (meet == null) return;

    try {
      if (state.isOwner) {
        await Navigator.push(
          context,
          CupertinoPageRoute(
            fullscreenDialog: true,
            builder: (_) => MeetCreateStepperView(meetId: meet.id),
          ),
        );
        await init();
        _refreshMeetList();
        return;
      }

      if (meet.status != 'open') return;

      if (state.isMember) {
        await leaveMeet();
        SnackbarService.show(
          type: AppSnackType.success,
          message: '모임 참가를 취소했어요',
        );
        return;
      }

      if (state.isFull) return;

      if (meet.needApproval) {
        if (state.isRequested) {
          await cancelJoinRequest();
          SnackbarService.show(
            type: AppSnackType.success,
            message: '참가 요청을 취소했어요',
          );
        } else {
          await requestJoin();
          SnackbarService.show(
            type: AppSnackType.success,
            message: '참가 요청을 보냈어요',
          );
        }
        return;
      }

      await joinNow();
      SnackbarService.show(type: AppSnackType.success, message: '모임에 참가했어요');
    } catch (e) {
      SnackbarService.show(
        type: AppSnackType.error,
        message: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  void _refreshMeetList() {
    try {
      ref.read(meetListControllerProvider.notifier).refresh();
    } catch (_) {}
  }
}
