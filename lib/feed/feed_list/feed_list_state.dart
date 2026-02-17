class FeedListState {
  final bool isLoading;
  final String selectMainType;
  final String selectSubType;
  final int refreshTick;
  final bool onlyFriendFeeds; // ✅ 추가
  FeedListState({
    this.isLoading = false,
    this.selectMainType = '전체',
    this.selectSubType = '전체',
    this.refreshTick = 0,required this.onlyFriendFeeds,
  });

  FeedListState copyWith({
    bool? isLoading,
    String? selectMainType,
    String? selectSubType,
    int? refreshTick,bool? onlyFriendFeeds,
  }) {
    return FeedListState(
      isLoading: isLoading ?? this.isLoading,
      selectMainType: selectMainType ?? this.selectMainType,
      selectSubType: selectSubType ?? this.selectSubType, onlyFriendFeeds: onlyFriendFeeds ?? this.onlyFriendFeeds,
      refreshTick: refreshTick ?? this.refreshTick,
    );
  }
}
