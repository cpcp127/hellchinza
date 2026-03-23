import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:hellchinza/meet/data/meet_repo.dart';
import 'package:hellchinza/meet/domain/meet_region.dart';

import 'package:hellchinza/services/image_service.dart';
import 'package:hellchinza/services/snackbar_service.dart';

import '../providers/meet_provider.dart';
import 'meet_create_state.dart';

class MeetCreateController extends StateNotifier<MeetCreateState> {
  MeetCreateController(this.ref, this._repo) : super(MeetCreateState.initial());

  final Ref ref;
  final MeetRepo _repo;

  Future<void> initForEdit(String meetId) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final meet = await _repo.fetchMeet(meetId);
      if (meet == null) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: '모임을 찾을 수 없어요',
        );
        return;
      }

      state = state.copyWith(
        isLoading: false,
        step: 0,
        editingMeetId: meet.id,
        title: meet.title,
        intro: meet.intro,
        category: meet.category,
        regions: meet.regions,
        maxMembersText: meet.maxMembers.toString(),
        needApproval: meet.needApproval,
        existingThumbnailUrl:
        meet.imageUrls.isNotEmpty ? meet.imageUrls.first : null,
        removeExistingThumbnail: false,
        clearThumbnail: true,
        errorMessage: null,
      );
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: '불러오기에 실패했어요',
      );
    }
  }

  void setTitle(String v) {
    state = state.copyWith(title: v, errorMessage: null);
  }

  void setIntro(String v) {
    state = state.copyWith(intro: v, errorMessage: null);
  }

  void selectCategory(String v) {
    state = state.copyWith(category: v, errorMessage: null);
  }

  void addRegion(MeetRegion r) {
    if (state.regions.any((e) => e.code == r.code)) return;
    state = state.copyWith(
      regions: [...state.regions, r],
      errorMessage: null,
    );
  }

  void removeRegion(String code) {
    state = state.copyWith(
      regions: state.regions.where((e) => e.code != code).toList(),
      errorMessage: null,
    );
  }

  void setMaxMembersText(String v) {
    final onlyDigits = v.replaceAll(RegExp(r'[^0-9]'), '');
    state = state.copyWith(
      maxMembersText: onlyDigits,
      errorMessage: null,
    );
  }

  void toggleNeedApproval(bool v) {
    state = state.copyWith(
      needApproval: v,
      errorMessage: null,
    );
  }

  Future<void> pickThumbnail(BuildContext context) async {
    final file = await ImageService().showImagePicker(context);
    if (file == null) return;

    final webpImage = await ImageService().convertToWebp(File(file.path));

    state = state.copyWith(
      thumbnail: webpImage,
      removeExistingThumbnail: false,
      errorMessage: null,
    );
  }

  void removeThumbnail() {
    if (state.thumbnail != null) {
      state = state.copyWith(
        clearThumbnail: true,
        errorMessage: null,
      );
      return;
    }

    if (state.existingThumbnailUrl != null) {
      state = state.copyWith(
        removeExistingThumbnail: true,
        errorMessage: null,
      );
    }
  }

  void back() {
    if (state.step <= 0) return;
    state = state.copyWith(
      step: state.step - 1,
      errorMessage: null,
    );
  }

  void next() {
    if (!state.canGoNext) {
      state = state.copyWith(errorMessage: _stepErrorMessage(state.step));
      return;
    }
    if (state.isLast) return;

    state = state.copyWith(
      step: state.step + 1,
      errorMessage: null,
    );
  }

  String _stepErrorMessage(int step) {
    switch (step) {
      case 0:
        return '모임 이름과 설명을 입력해주세요';
      case 1:
        return '운동 종류를 선택해주세요';
      case 2:
        return '주요 활동 지역을 1개 이상 추가해주세요';
      case 3:
        return '최대 인원을 2~1000 사이 숫자로 입력해주세요';
      case 5:
        return '썸네일을 등록해주세요';
      default:
        return '필수 정보를 확인해주세요';
    }
  }

  Future<void> submit() async {
    if (!state.isLast || !state.canGoNext) {
      state = state.copyWith(errorMessage: _stepErrorMessage(state.step));
      return;
    }

    final uid = _repo.currentUid;
    if (uid == null) {
      state = state.copyWith(errorMessage: '로그인이 필요해요');
      return;
    }

    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      await _repo.saveMeet(
        uid: uid,
        title: state.title,
        intro: state.intro,
        category: state.category!,
        regions: state.regions,
        maxMembers: int.parse(state.maxMembersText.trim()),
        needApproval: state.needApproval,
        editingMeetId: state.editingMeetId,
        thumbnail: state.thumbnail,
        removeExistingThumbnail: state.removeExistingThumbnail,
      );

      state = state.copyWith(isLoading: false);

      try {
        ref.read(meetListControllerProvider.notifier).refresh();
      } catch (_) {}

      SnackbarService.show(
        type: AppSnackType.success,
        message: state.isEdit ? '모임 수정에 성공했어요!' : '모임 생성에 성공했어요!',
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: '저장에 실패했어요',
      );

      SnackbarService.show(
        type: AppSnackType.error,
        message: '저장에 실패했어요',
      );
    }
  }
}