import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../providers/feed_provider.dart';
import 'feed_list_state.dart';

class FeedListController extends StateNotifier<FeedListState> {
  FeedListController(this.ref) : super(const FeedListState());

  final Ref ref;

  static const _pageSize = 10;

  Future<void> onChangeMainType(String type) async {
    state = state.copyWith(selectMainType: type);
  }

  Future<void> onChangeSubType(String type) async {
    state = state.copyWith(selectSubType: type);
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
      refreshTick: state.refreshTick + 1,
    );
  }

  String makeQueryKey({
    required List<String> blockedUids,
    required List<String> friendUids,
  }) {
    final sortedBlocked = [...blockedUids]..sort();
    final sortedFriends = [...friendUids]..sort();

    return '${state.selectMainType}_${state.selectSubType}_${state.refreshTick}_${state.onlyFriendFeeds}_${sortedBlocked.join(",")}_${sortedFriends.join(",")}';
  }

  Future<void> resetAndFetch({
    required List<String> blockedUids,
    required List<String> friendUids,
  }) async {
    if (state.isLoading) return;

    state = state.copyWith(
      isLoading: true,
      isLoadingMore: false,
      hasMore: true,
      items: const [],
      clearLastDoc: true,
    );

    try {
      final result = await ref
          .read(feedRepoProvider)
          .fetchFeedPage(
            mainType: state.selectMainType,
            subType: state.selectSubType,
            onlyFriendFeeds: state.onlyFriendFeeds,
            blockedUids: blockedUids,
            friendUids: friendUids,
            pageSize: _pageSize,
          );

      state = state.copyWith(
        isLoading: false,
        items: result.items,
        lastDoc: result.lastDoc,
        hasMore: result.hasMore,
      );
    } catch (_) {
      state = state.copyWith(isLoading: false, hasMore: false);
    }
  }

  Future<void> fetchNextPage({
    required List<String> blockedUids,
    required List<String> friendUids,
  }) async {
    if (state.isLoading || state.isLoadingMore || !state.hasMore) return;
    if (state.lastDoc == null) return;

    state = state.copyWith(isLoadingMore: true);

    try {
      final result = await ref
          .read(feedRepoProvider)
          .fetchFeedPage(
            mainType: state.selectMainType,
            subType: state.selectSubType,
            onlyFriendFeeds: state.onlyFriendFeeds,
            blockedUids: blockedUids,
            friendUids: friendUids,
            pageSize: _pageSize,
            startAfter: state.lastDoc,
          );

      state = state.copyWith(
        isLoadingMore: false,
        items: [...state.items, ...result.items],
        lastDoc: result.lastDoc,
        hasMore: result.hasMore,
      );
    } catch (_) {
      state = state.copyWith(isLoadingMore: false);
    }
  }
}
