import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import '../../feed/create_feed/create_feed_state.dart';


class LightningCreateState {
  final int stepIndex; // 0~4

  final bool isLoading;
  final String? errorMessage;

  final String title;
  final String? category; // workList 선택
  final DateTime? dateTime;

  final int? maxMembersText; // 텍스트필드에서 파싱된 값
  final FeedPlace? selectedPlace;

  final XFile? thumbnail;

  const LightningCreateState({
    required this.stepIndex,
    required this.isLoading,
    required this.errorMessage,
    required this.title,
    required this.category,
    required this.dateTime,
    required this.maxMembersText,
    this.selectedPlace,
    required this.thumbnail,
  });

  const LightningCreateState.initial()
      : stepIndex = 0,
        isLoading = false,
        errorMessage = null,
        title = '',
        category = null,
        dateTime = null,
        maxMembersText = null,
        selectedPlace = null,
        thumbnail = null;

  LightningCreateState copyWith({
    int? stepIndex,
    bool? isLoading,
    String? errorMessage,
    String? title,
    String? category,
    DateTime? dateTime,
    int? maxMembersText,
    FeedPlace? selectedPlace,
    XFile? thumbnail,
    bool clearError = false,
    bool clearThumbnail = false,
  }) {
    return LightningCreateState(
      stepIndex: stepIndex ?? this.stepIndex,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      title: title ?? this.title,
      category: category ?? this.category,
      dateTime: dateTime ?? this.dateTime,
      maxMembersText: maxMembersText ?? this.maxMembersText,
      selectedPlace: selectedPlace ?? this.selectedPlace,
      thumbnail: clearThumbnail ? null : (thumbnail ?? this.thumbnail),
    );
  }

  // ✅ step별 검증
  bool get canGoNext {
    switch (stepIndex) {
      case 0:
        return title.trim().isNotEmpty;
      case 1:
        return category != null && category!.isNotEmpty;
      case 2:
        return dateTime != null && dateTime!.isAfter(DateTime.now().subtract(const Duration(minutes: 1)));
      case 3:
        final v = maxMembersText;
        return v != null && v >= 2 && v <= 200;
      case 4:
        return selectedPlace != null;
      default:
        return false;
    }
  }

  bool get isLast => stepIndex >= 4;

  bool get canSubmit => canGoNext && isLast && !isLoading;
}
