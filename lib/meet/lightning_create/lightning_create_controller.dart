import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:hellchinza/feed/domain/feed_place.dart';
import 'package:hellchinza/meet/data/meet_repo.dart';
import 'package:hellchinza/services/image_service.dart';
import 'package:hellchinza/services/snackbar_service.dart';

import 'lightning_create_state.dart';

class LightningCreateController extends StateNotifier<LightningCreateState> {
  LightningCreateController(this.ref, this._repo, this.meetId)
    : super(const LightningCreateState.initial());

  final Ref ref;
  final MeetRepo _repo;
  final String meetId;

  void onChangeTitle(String v) {
    state = state.copyWith(title: v, clearError: true);
  }

  void onSelectCategory(String v) {
    state = state.copyWith(category: v, clearError: true);
  }

  void onSelectDateTime(DateTime v) {
    state = state.copyWith(dateTime: v, clearError: true);
  }

  void onChangeMaxMembersText(String raw) {
    final trimmed = raw.trim();
    final parsed = int.tryParse(trimmed);
    state = state.copyWith(maxMembersText: parsed, clearError: true);
  }

  void onSelectPlace(FeedPlace place) {
    state = state.copyWith(selectedPlace: place, clearError: true);
  }

  Future<void> pickThumbnailToAlbum(BuildContext context) async {
    final file = await ImageService().showImagePicker(context);
    if (file == null) return;

    final webpImage = await ImageService().convertToWebp(File(file.path));
    state = state.copyWith(thumbnail: webpImage, clearError: true);
  }

  Future<void> pickThumbnailToAlbumToCamera(BuildContext context) async {
    final file = await ImageService().takePicture(context);
    if (file == null) return;

    final webpImage = await ImageService().convertToWebp(File(file.path));
    state = state.copyWith(thumbnail: webpImage, clearError: true);
  }

  void removeThumbnail() {
    state = state.copyWith(clearThumbnail: true, clearError: true);
  }

  void nextStep() {
    if (!state.canGoNext) return;
    state = state.copyWith(stepIndex: state.stepIndex + 1);
  }

  void prevStep() {
    if (state.stepIndex <= 0) return;
    state = state.copyWith(stepIndex: state.stepIndex - 1);
  }

  void onTapLeading(BuildContext context) {
    if (state.stepIndex == 0) {
      Navigator.pop(context);
      return;
    }
    prevStep();
  }

  Future<bool> submit() async {
    if (!state.canSubmit) {
      state = state.copyWith(errorMessage: '필수 항목을 확인해주세요.');
      return false;
    }

    final uid = _repo.currentUid;
    if (uid == null) {
      state = state.copyWith(errorMessage: '로그인이 필요합니다.');
      return false;
    }

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      await _repo.createLightning(
        meetId: meetId,
        authorUid: uid,
        title: state.title,
        category: state.category!,
        dateTime: state.dateTime!,
        maxMembers: state.maxMembersText!,
        place: state.selectedPlace,
        thumbnail: state.thumbnail,
      );

      state = state.copyWith(isLoading: false);

      SnackbarService.show(
        type: AppSnackType.success,
        message: '번개 생성에 성공했어요!',
      );
      return true;
    } catch (_) {
      state = state.copyWith(isLoading: false, errorMessage: '번개 생성에 실패했어요.');

      SnackbarService.show(type: AppSnackType.error, message: '번개 생성에 실패했어요.');
      return false;
    }
  }
}
