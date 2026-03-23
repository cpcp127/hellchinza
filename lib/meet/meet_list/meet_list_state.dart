import 'package:flutter/foundation.dart';

import '../domain/meet_summary_model.dart';

@immutable
class MeetListState {
  final bool isLoading;
  final bool isRefreshing;
  final bool hasMore;
  final String? errorMessage;

  final List<MeetSummary> items;
  final String selectSubType;
  final int refreshTick; // ✅ 추가
  final String searchText;

  const MeetListState({
    required this.isLoading,
    required this.isRefreshing,
    required this.hasMore,
    required this.items,
    required this.refreshTick,
    required this.errorMessage,
    this.selectSubType = '전체',
    required this.searchText,
  });

  const MeetListState.initial()
    : isLoading = false,
      isRefreshing = false,
      hasMore = true,
      items = const [],
      selectSubType = '전체',
      refreshTick = 0,
      searchText = '',
      errorMessage = null;

  MeetListState copyWith({
    bool? isLoading,
    bool? isRefreshing,
    bool? hasMore,
    List<MeetSummary>? items,
    String? errorMessage,
    bool clearError = false,
    String? selectSubType,
    int? refreshTick,
    String? searchText,
  }) {
    return MeetListState(
      isLoading: isLoading ?? this.isLoading,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      hasMore: hasMore ?? this.hasMore,
      items: items ?? this.items,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      selectSubType: selectSubType ?? this.selectSubType,
      refreshTick: refreshTick ?? this.refreshTick,
      searchText: searchText ?? this.searchText,
    );
  }
}
