class FeedListState {
  final bool isLoading;
  final String selectMainType;
  final String selectSubType;
  final int refreshTick;

  FeedListState({
    this.isLoading = false,
    this.selectMainType = '전체',
    this.selectSubType = '전체',
    this.refreshTick = 0,
  });

  FeedListState copyWith({
    bool? isLoading,
    String? selectMainType,
    String? selectSubType,
    int? refreshTick,
  }) {
    return FeedListState(
      isLoading: isLoading ?? this.isLoading,
      selectMainType: selectMainType ?? this.selectMainType,
      selectSubType: selectSubType ?? this.selectSubType,
      refreshTick: refreshTick ?? this.refreshTick,
    );
  }
}
