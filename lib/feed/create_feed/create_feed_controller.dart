import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:hellchinza/feed/create_feed/create_feed_state.dart';
import 'package:hellchinza/feed/feed_list/feed_list_controller.dart';
import 'package:hellchinza/meet/meet_detail/meat_detail_controller.dart';
import 'package:hellchinza/services/image_service.dart';

import '../../services/naver_location_service.dart';
import '../../services/snackbar_service.dart';
import '../../services/storage_upload_service.dart';
import '../domain/feed_model.dart';
import 'package:proj4dart/proj4dart.dart' as proj4;

final createFeedControllerProvider =
    StateNotifierProvider.autoDispose<CreateFeedController, CreateFeedState>((
      ref,
    ) {
      return CreateFeedController(ref);
    });

class CreateFeedController extends StateNotifier<CreateFeedState> {
  final Ref ref;
  KeepAliveLink? _keepAlive;
  CreateFeedController(this.ref) : super(CreateFeedState());

  void onChangeMainType(String type) {
    state = state.copyWith(selectMainType: type);

    if (type != '후기') {
      state = state.copyWith(selectedPlace: null);
    }
  }


  void onChangeSubType(String type) {
    state = state.copyWith(selectSubType: type);
  }

  Future<void> pickMultiImage() async {
    final existingCount = state.existingImageUrls?.length ?? 0;
    final newCount = state.newImageFiles?.length ?? 0;
    final totalCount = existingCount + newCount;

    // ✅ 이미 10장이면 막기
    if (totalCount >= 10) {
      return;
    }

    // ✅ 남은 개수만큼만 picker 허용
    final remainCount = 10 - totalCount;

    final List<XFile>? pickedList =
    await ImageService().showMultiImagePicker(remainCount);

    if (pickedList == null || pickedList.isEmpty) return;

    // 혹시 picker에서 더 많이 넘어와도 방어
    final List<XFile> toAdd = pickedList.take(remainCount).toList();

    state = state.copyWith(
      newImageFiles: [
        ...state.newImageFiles ?? [],
        ...toAdd,
      ],
    );
  }




  void onChangeImageIndex(int index) {
    state = state.copyWith(currentImageIndex: index);
  }

  void onChangeText(String text) {
    state = state.copyWith(contents: text);
  }

  void onTapNext() {
    state = state.copyWith(pageIndex: 1);
  }

  void onTapBack() {
    state = state.resetForTypeSelect();
    state = state.copyWith(pageIndex: 0);
  }

  void ensurePollDefaults() {
    List<String>? list = state.pollOptions ?? [];
    if (list.isEmpty) {
      state = state.copyWith(pollOptions: ['', '']); // 기본 2개
    }
  }

  void addPollOption() {
    List<String>? list = [...(state.pollOptions ?? [])];

    // 처음 시작할 때는 2개부터
    if (list.isEmpty) {
      state = state.copyWith(pollOptions: ['', '']);
      return;
    }

    if (list.length >= 6) {
      return;
    }

    list.add('');
    state = state.copyWith(pollOptions: list);
  }

  void removePollOptionAt(int index) {
    List<String>? list = [...(state.pollOptions ?? [])];
    if (list.length <= 2) return; // 최소 2개 유지
    if (index < 0 || index >= list.length) return;

    list.removeAt(index);
    state = state.copyWith(pollOptions: list);
  }

  void changePollOption(int index, String value) {
    List<String>? list = [...(state.pollOptions ?? [])];
    if (index < 0 || index >= list.length) return;

    list[index] = value;
    state = state.copyWith(pollOptions: list);
  }

  Future<void> submitFeed(BuildContext context,String? meetId) async {
    _keepAlive ??= ref.keepAlive();

    final progress = ValueNotifier<double>(0);

    // 1️⃣ 먼저 페이지 pop
    Navigator.pop(context);

    // 2️⃣ 업로드 중 snackbar
    SnackbarService.show(
      type: AppSnackType.uploading,
      message: '업로드 중입니다...',
      progress: progress,
    );

    try {
      await _submitFeedInternal(
        onProgress: (p) => progress.value = p,meetId: meetId
      );

      SnackbarService.dismiss();

      SnackbarService.show(
        type: AppSnackType.success,
        message: '업로드가 완료되었습니다!',
      );
      if(meetId==null){
        ref.read(feedListControllerProvider.notifier).refresh();
      }else{
        ref.read(meetDetailControllerProvider(meetId).notifier).init();
      }
    } catch (e, st) {
      SnackbarService.dismiss();

      SnackbarService.show(
        type: AppSnackType.error,
        message: '업로드에 실패했습니다. 다시 시도해주세요.',
      );

      debugPrint('submitFeed error: $e\n$st');
    } finally {
      progress.dispose();
      _keepAlive?.close();
      _keepAlive = null;
    }
  }


  Future<void> _submitFeedInternal({
    required ValueChanged<double> onProgress,required String? meetId
  }) async {
    final user = FirebaseAuth.instance.currentUser!;
    final feedRef = FirebaseFirestore.instance.collection('feeds').doc();
    final feedId = feedRef.id;

    // 0% 시작
    onProgress(0);
    Map<String, dynamic>? placeJson;


    // 1) Firestore 먼저 생성 (이미지 없음)
    await feedRef.set({
      'id': feedId,
      'authorUid': user.uid,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),

      'mainType': state.selectMainType,
      'subType': state.selectSubType,
      'contents': state.contents,

      'imageUrls': null,
      'likeUids': <String>[],

      'poll': _buildPollMapOrNull(state.pollOptions),
      'place': state.selectedPlace?.toJson(),
      'commentCount':0,
      'meetId':meetId,
    });

    // 2) 이미지 업로드 (있을 때만)
    List<String>? imageUrls;
    final files = state.newImageFiles;

    if (files != null && files.isNotEmpty) {
      final results = await const StorageUploadService().uploadFeedImagesWithProgress(
        feedId: feedId,
        uid: user.uid,
        files: files,
        onProgress: onProgress,
      );
      imageUrls = results.map((e) => e.url).toList();
    } else {
      // 이미지 없으면 진행률 100%로 처리
      onProgress(1);
    }

    // 3) Firestore 업데이트 (imageUrls 반영)
    await feedRef.update({
      'imageUrls': imageUrls,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Map<String, dynamic>? _buildPollMapOrNull(List<String>? pollOptions) {
    if (pollOptions == null) return null;

    final cleaned = pollOptions.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    if (cleaned.length < 2) return null;

    return {
      'options': cleaned.asMap().entries.map((e) {
        return {
          'id': 'option_${e.key + 1}',
          'text': e.value,
          'voterUids': <String>[],
        };
      }).toList(),
    };
  }
  void onSelectPlace(FeedPlace place) {
    state = state.copyWith(selectedPlace: place);
  }
  //편집
  void initForEdit(FeedModel feed) {
    state = state.copyWith(
      pageIndex: 0,
      selectMainType: feed.mainType,
      selectSubType: feed.subType,
      contents: feed.contents,
      pollOptions: feed.poll?.options.map((e) => e.text).toList(),
      existingImageUrls: feed.imageUrls ?? [],
      newImageFiles: [],
      removedImageUrls: [],
      selectedPlace: feed.place,
      // ❗️이미지는 URL → XFile 변환이 어려우므로
      // 수정 시 "기존 이미지 유지 / 새로 추가" 구조로 나중에 분리


    );
    print(state.existingImageUrls);
  }

  void removeImageAt(int index) {
    // 기존 이미지 영역
    if (index < (state.existingImageUrls?.length ?? 0)) {
      final removedUrl = state.existingImageUrls![index];

      state = state.copyWith(
        existingImageUrls: [
          ...state.existingImageUrls!..removeAt(index),
        ],
        removedImageUrls: [
          ...state.removedImageUrls ?? [],
          removedUrl,
        ],
      );
    }
    // 새로 추가한 이미지 영역
    else {
      final newIndex = index - state.existingImageUrls!.length;
      final newFiles = [...state.newImageFiles!..removeAt(newIndex)];

      state = state.copyWith(newImageFiles: newFiles);
    }
  }

  Future<void> updateFeed(BuildContext context, {required String feedId}) async {
    _keepAlive ??= ref.keepAlive();

    final progress = ValueNotifier<double>(0);

    // 1️⃣ 먼저 페이지 pop
    Navigator.pop(context);

    // 2️⃣ 업로드(수정) 중 snackbar
    SnackbarService.show(
      type: AppSnackType.uploading,
      message: '수정 중입니다...',
      progress: progress,
    );

    try {
      await _updateFeedInternal(
        feedId: feedId,
        onProgress: (p) => progress.value = p,
      );

      SnackbarService.dismiss();
      SnackbarService.show(
        type: AppSnackType.success,
        message: '수정이 완료되었습니다!',
      );
    } catch (e, st) {
      SnackbarService.dismiss();
      SnackbarService.show(
        type: AppSnackType.error,
        message: '수정에 실패했습니다. 다시 시도해주세요.',
      );
      debugPrint('updateFeed error: $e\n$st');
    } finally {
      progress.dispose();
      _keepAlive?.close();
      _keepAlive = null;
    }
  }

  Future<void> _updateFeedInternal({
    required String feedId,
    required ValueChanged<double> onProgress,
  }) async {
    final feedRef = FirebaseFirestore.instance.collection('feeds').doc(feedId);
    final storage = FirebaseStorage.instance;

    // 0% 시작
    onProgress(0);

    // 1) 삭제된 기존 이미지 Storage 삭제 (에러 나도 계속 진행)
    final removed = state.removedImageUrls ?? const <String>[];
    for (final url in removed) {
      try {
        await storage.refFromURL(url).delete();
      } catch (_) {
        // 이미 삭제됐거나 권한/네트워크 이슈 -> 무시하고 진행
      }
    }

    // 2) 새 이미지 업로드 (progress 반영)
    final newFiles = state.newImageFiles ?? const <XFile>[];
    List<String> uploadedUrls = [];

    if (newFiles.isNotEmpty) {
      final results =
      await const StorageUploadService().uploadFeedImagesWithProgress(
        feedId: feedId,
        uid: FirebaseAuth.instance.currentUser!.uid,
        files: newFiles,
        onProgress: onProgress, // ✅ 진행률 표시
      );
      uploadedUrls = results.map((e) => e.url).toList();
    } else {
      // 새 이미지 없으면 진행률 100%로
      onProgress(1);
    }

    // 3) 최종 이미지 URL 리스트 구성
    final keptExisting = state.existingImageUrls ?? const <String>[];
    final finalImageUrls = <String>[
      ...keptExisting,
      ...uploadedUrls,
    ];



    // 4) Firestore 업데이트 (타입/내용/투표/이미지 반영)
    await feedRef.update({
      'mainType': state.selectMainType,
      'subType': state.selectSubType,
      'contents': state.contents,
      'poll': _buildPollMapOrNull(state.pollOptions),
      'imageUrls': finalImageUrls.isEmpty ? null : finalImageUrls,
      'updatedAt': FieldValue.serverTimestamp(),
      'place': state.selectedPlace?.toJson(),
    });
  }






}
