import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:image_picker/image_picker.dart';

import '../../feed/create_feed/create_feed_state.dart';
import '../../services/image_service.dart';
import '../../services/snackbar_service.dart';
import 'lightning_create_state.dart';



final lightningCreateControllerProvider = StateNotifierProvider.autoDispose
    .family<LightningCreateController, LightningCreateState, String>((ref, meetId) {
  return LightningCreateController(ref, meetId);
});

class LightningCreateController extends StateNotifier<LightningCreateState> {
  LightningCreateController(this.ref, this.meetId) : super(const LightningCreateState.initial());

  final Ref ref;
  final String meetId;

  final _db = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;

  // ✅ 입력 업데이트
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
    // digitsOnly로 막아도 혹시 몰라 안전 파싱
    final trimmed = raw.trim();
    final parsed = int.tryParse(trimmed);
    state = state.copyWith(maxMembersText: parsed, clearError: true);
  }

  void onSelectPlace(FeedPlace place) {
    state = state.copyWith(selectedPlace: place);
  }

  Future<void> pickThumbnailToAlbum() async {

    final file = await ImageService().showImagePicker();
    if (file == null) return;
    state = state.copyWith(thumbnail: file, clearError: true);
  }
  Future<void> pickThumbnailToAlbumToCamera() async {

    final file = await ImageService().takePicture();
    if (file == null) return;
    state = state.copyWith(thumbnail: file, clearError: true);
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

  // ✅ submit: Firestore + (optional) Storage thumbnail
  Future<bool> submit() async {
    if (!state.canSubmit) {
      state = state.copyWith(errorMessage: '필수 항목을 확인해주세요.');
      return false;
    }

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      state = state.copyWith(errorMessage: '로그인이 필요합니다.');
      return false;
    }

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final lightningRef = _db
          .collection('meets')
          .doc(meetId)
          .collection('lightnings')
          .doc();

      final lightningId = lightningRef.id;

      // 1) 썸네일 업로드(선택)
      List<String> imageUrls = [];
      if (state.thumbnail != null) {
        final url = await _uploadLightningThumb(
          meetId: meetId,
          lightningId: lightningId,
          file: state.thumbnail!,
        );
        imageUrls = [url];
      }

      // 2) 문서 생성
      final data = <String, dynamic>{
        'id': lightningId,
        'meetId': meetId,
        'authorUid': uid,

        'title': state.title.trim(),
        'category': state.category, // workList
        'dateTime': Timestamp.fromDate(state.dateTime!),

        'maxMembers': state.maxMembersText!,
        'currentMemberCount': 1,
        'memberUids': [uid],

        'place': state.selectedPlace?.toJson(),

        'imageUrls': imageUrls,
        'status': 'open',

        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await lightningRef.set(data);

      state = state.copyWith(isLoading: false);
      SnackbarService.show(
        type: AppSnackType.success,
        message: '번개 생성에 성공했어요!',
      );
      return true;
    } catch (e) {
      SnackbarService.show(
        type: AppSnackType.error,
        message: '번개 생성에 실패했어요',
      );
      state = state.copyWith(isLoading: false, errorMessage: '번개 생성에 실패했어요');
      return false;
    }
  }

  Future<String> _uploadLightningThumb({
    required String meetId,
    required String lightningId,
    required XFile file,
  }) async {
    final ref = _storage
        .ref()
        .child('meets/$meetId/lightnings/$lightningId/thumb.webp');

    // 파일 업로드
    final task = await ref.putFile(File(file.path));
    if (task.state != TaskState.success) {
      throw Exception('thumbnail upload failed');
    }

    return await ref.getDownloadURL();
  }

  void onTapLeading(BuildContext context) {
    if (state.stepIndex == 0) {
      Navigator.pop(context);
      return;
    }
    prevStep();
  }

}
