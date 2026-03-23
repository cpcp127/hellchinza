import 'package:flutter/foundation.dart';

class MeetListState {
  final String selectSubType;
  final int refreshTick;
  final String searchText;

  const MeetListState({
    this.selectSubType = '전체',
    this.refreshTick = 0,
    this.searchText = '',
  });

  const MeetListState.initial()
    : selectSubType = '전체',
      refreshTick = 0,
      searchText = '';

  MeetListState copyWith({
    String? selectSubType,
    int? refreshTick,
    String? searchText,
  }) {
    return MeetListState(
      selectSubType: selectSubType ?? this.selectSubType,
      refreshTick: refreshTick ?? this.refreshTick,
      searchText: searchText ?? this.searchText,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is MeetListState &&
            other.selectSubType == selectSubType &&
            other.refreshTick == refreshTick &&
            other.searchText == searchText);
  }

  @override
  int get hashCode => Object.hash(selectSubType, refreshTick, searchText);
}
