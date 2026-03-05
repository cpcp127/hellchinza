import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:hellchinza/feed/feed_list/feed_list_state.dart';

final feedListControllerProvider =
    StateNotifierProvider.autoDispose<FeedListController, FeedListState>((ref) {
      return FeedListController(ref);
    });

class FeedListController extends StateNotifier<FeedListState> {
  final Ref ref;

  FeedListController(this.ref) : super(FeedListState(onlyFriendFeeds: false));

  Future<void> onChangeMainType(String type) async {
    state = state.copyWith(selectMainType: type);
  }

  Future<void> onChangeSubType(String type) async {
    state = state.copyWith(selectSubType: type);
  }

  Query<Map<String, dynamic>> buildFeedQuery() {
    Query<Map<String, dynamic>> query = FirebaseFirestore.instance.collection(
      'feeds',
    );

    if (state.selectMainType != '전체') {
      query = query.where('mainType', isEqualTo: state.selectMainType);
    }

    if (state.selectMainType != '식단' && state.selectSubType != '전체') {
      query = query.where('subType', isEqualTo: state.selectSubType);
    }

    query = query.orderBy('createdAt', descending: true);

    query = query.where('meetId', isNull: true);

    // // ✅ 친구 피드만 보기
    // if (state.onlyFriendFeeds) {
    //   if (friendUids.isEmpty) {
    //     // 친구가 없으면 "빈 결과"로
    //     return query.where('authorUid', isEqualTo: '__none__');
    //   }
    //
    //   // Firestore whereIn 제한(10개)
    //   if (friendUids.length <= 10) {
    //     return query.where('authorUid', whereIn: friendUids);
    //   }
    //
    //
    //   return query;
    // }

    return query;
  }

  void refresh() {
    state = state.copyWith(refreshTick: state.refreshTick + 1);
  }

  void toggleOnlyFriendFeeds(bool on) {
    state = state.copyWith(
      onlyFriendFeeds: on,
      refreshTick: state.refreshTick + 1,
    );
  }

  void applyFilters({
    required String mainType,
    required String subType,
    required bool onlyFriends,
  }) {
    state = state.copyWith(
      selectMainType: mainType,
      selectSubType: subType,
      onlyFriendFeeds: onlyFriends,
      refreshTick: state.refreshTick + 1, // ✅ pagination 강제 새로고침
    );
  }
}
