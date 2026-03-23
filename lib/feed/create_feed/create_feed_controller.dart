import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_riverpod/misc.dart';

import '../../../oow_step/presentation/oow_step_view.dart';
import '../../../services/image_service.dart';
import '../../../services/snackbar_service.dart';
import '../../meet/meet_detail/meat_detail_view.dart';
import '../../meet/providers/meet_provider.dart';
import '../../oow_step/providers/oow_provider.dart';
import '../domain/feed_model.dart';
import '../domain/feed_place.dart';
import '../providers/feed_provider.dart';
import 'create_feed_state.dart';

class CreateFeedController extends StateNotifier<CreateFeedState> {
  CreateFeedController(this.ref) : super(const CreateFeedState());

  final Ref ref;
  KeepAliveLink? _keepAlive;

  void onChangeMainType(String type) {
    state = state.copyWith(selectMainType: type);
    if (type != '후기') {
      state = state.copyWith(clearPlace: true);
    }
  }

  void onChangeSubType(String type) {
    state = state.copyWith(selectSubType: type);
  }

  Future<void> pickMultiImage(BuildContext context) async {
    final totalCount =
        state.existingImageUrls.length + state.newImageFiles.length;
    if (totalCount >= 10) return;

    final remainCount = 10 - totalCount;
    final pickedList = await ImageService().showMultiImagePicker(
      context,
      remainCount,
    );
    if (pickedList == null || pickedList.isEmpty) return;

    final toAdd = pickedList.take(remainCount).toList();
    final result = <dynamic>[];

    for (final img in toAdd) {
      final webp = await ImageService().convertToWebp(File(img.path));
      result.add(webp);
    }

    state = state.copyWith(
      newImageFiles: [...state.newImageFiles, ...result.cast()],
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
  }

  void ensurePollDefaults() {
    if (state.pollOptions.isEmpty) {
      state = state.copyWith(pollOptions: ['', '']);
    }
  }

  void addPollOption() {
    final list = [...state.pollOptions];

    if (list.isEmpty) {
      state = state.copyWith(pollOptions: ['', '']);
      return;
    }

    if (list.length >= 6) return;

    list.add('');
    state = state.copyWith(pollOptions: list);
  }

  void removePollOptionAt(int index) {
    final list = [...state.pollOptions];
    if (list.length <= 2) return;
    if (index < 0 || index >= list.length) return;

    list.removeAt(index);
    state = state.copyWith(pollOptions: list);
  }

  void changePollOption(int index, String value) {
    final list = [...state.pollOptions];
    if (index < 0 || index >= list.length) return;

    list[index] = value;
    state = state.copyWith(pollOptions: list);
  }

  void onSelectPlace(FeedPlace place) {
    state = state.copyWith(selectedPlace: place);
  }

  void onChangeVisibility(String visibility) {
    state = state.copyWith(visibility: visibility);
  }

  void initForEdit(FeedModel feed) {
    state = state.copyWith(
      pageIndex: 0,
      selectMainType: feed.mainType,
      selectSubType: feed.subType,
      contents: feed.contents ?? '',
      pollOptions: feed.poll?.options.map((e) => e.text).toList() ?? const [],
      existingImageUrls: feed.imageUrls,
      newImageFiles: const [],
      removedImageUrls: const [],
      selectedPlace: feed.place,
      visibility: feed.visibility,
    );
  }

  void removeImageAt(int index) {
    if (index < state.existingImageUrls.length) {
      final removedUrl = state.existingImageUrls[index];
      final nextExisting = [...state.existingImageUrls]..removeAt(index);

      state = state.copyWith(
        existingImageUrls: nextExisting,
        removedImageUrls: [...state.removedImageUrls, removedUrl],
      );
      return;
    }

    final newIndex = index - state.existingImageUrls.length;
    final nextFiles = [...state.newImageFiles]..removeAt(newIndex);

    state = state.copyWith(newImageFiles: nextFiles);
  }

  Future<void> submitFeed(BuildContext context, String? meetId) async {
    _keepAlive ??= ref.keepAlive();
    final progress = ValueNotifier<double>(0);

    Navigator.pop(context);

    SnackbarService.show(
      type: AppSnackType.uploading,
      message: '업로드 중입니다...',
      progress: progress,
    );

    try {
      await ref
          .read(feedRepoProvider)
          .createFeed(
            mainType: state.selectMainType ?? '',
            subType: state.selectSubType,
            contents: state.contents,
            newImageFiles: state.newImageFiles,
            pollOptions: state.pollOptions,
            selectedPlace: state.selectedPlace,
            visibility: state.visibility,
            meetId: meetId,
            onProgress: (p) => progress.value = p,
          );

      SnackbarService.dismiss();
      SnackbarService.show(
        type: AppSnackType.success,
        message: '업로드가 완료되었습니다!',
      );

      if (state.selectMainType == '오운완') {
        ref
            .read(
              oowRefreshTickProvider(
                ref.read(feedRepoProvider).currentUidOrThrow,
              ).notifier,
            )
            .state++;
      }

      if (meetId == null) {
        ref.read(feedListControllerProvider.notifier).refresh();
      } else {
        ref.invalidate(meetPhotoFeedSectionProvider(meetId));
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

  Future<void> updateFeed(
    BuildContext context, {
    required String feedId,
    String? meetId,
  }) async {
    _keepAlive ??= ref.keepAlive();
    final progress = ValueNotifier<double>(0);

    Navigator.pop(context);

    SnackbarService.show(
      type: AppSnackType.uploading,
      message: '수정 중입니다...',
      progress: progress,
    );

    try {
      await ref
          .read(feedRepoProvider)
          .updateFeed(
            feedId: feedId,
            mainType: state.selectMainType ?? '',
            subType: state.selectSubType,
            contents: state.contents,
            existingImageUrls: state.existingImageUrls,
            newImageFiles: state.newImageFiles,
            removedImageUrls: state.removedImageUrls,
            pollOptions: state.pollOptions,
            selectedPlace: state.selectedPlace,
            visibility: state.visibility,
            onProgress: (p) => progress.value = p,
          );

      SnackbarService.dismiss();
      SnackbarService.show(type: AppSnackType.success, message: '수정이 완료되었습니다!');

      if (state.selectMainType == '오운완') {
        ref
            .read(
              oowRefreshTickProvider(
                ref.read(feedRepoProvider).currentUidOrThrow,
              ).notifier,
            )
            .state++;
      }

      if (meetId == null) {
        ref.read(feedListControllerProvider.notifier).refresh();
      } else {
        ref.invalidate(meetPhotoFeedSectionProvider(meetId));
      }
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
}
