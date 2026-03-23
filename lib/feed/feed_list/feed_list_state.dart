import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/feed_model.dart';

class FeedListState {
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final String selectMainType;
  final String selectSubType;
  final int refreshTick;
  final bool onlyFriendFeeds;
  final List<FeedModel> items;
  final DocumentSnapshot<Map<String, dynamic>>? lastDoc;

  const FeedListState({
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.selectMainType = '전체',
    this.selectSubType = '전체',
    this.refreshTick = 0,
    this.onlyFriendFeeds = false,
    this.items = const [],
    this.lastDoc,
  });

  FeedListState copyWith({
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    String? selectMainType,
    String? selectSubType,
    int? refreshTick,
    bool? onlyFriendFeeds,
    List<FeedModel>? items,
    DocumentSnapshot<Map<String, dynamic>>? lastDoc,
    bool clearLastDoc = false,
  }) {
    return FeedListState(
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      selectMainType: selectMainType ?? this.selectMainType,
      selectSubType: selectSubType ?? this.selectSubType,
      refreshTick: refreshTick ?? this.refreshTick,
      onlyFriendFeeds: onlyFriendFeeds ?? this.onlyFriendFeeds,
      items: items ?? this.items,
      lastDoc: clearLastDoc ? null : (lastDoc ?? this.lastDoc),
    );
  }
}
