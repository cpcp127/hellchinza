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



  void toggleOnlyFriendFeeds(bool on) {
    state = state.copyWith(
      onlyFriendFeeds: on,
      refreshTick: state.refreshTick + 1,
    );
    resetAndFetch(); // 상태 변경 후 즉시 새 데이터 로드
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
    resetAndFetch(); // 필터 적용 후 컨트롤러가 알아서 데이터 리프레시
  }

  // 외부 파라미터 주입을 없애고 컨트롤러가 스스로 데이터를 가져오도록 변경
  // feed_list_controller.dart 의 함수 2개를 아래와 같이 수정해 주세요.

  Future<void> resetAndFetch() async {
    if (state.isLoading) return;

    state = state.copyWith(
      isLoading: true,
      isLoadingMore: false,
      hasMore: true,
      items: const [],
      clearLastDoc: true,
    );

    try {
      final blockedUids = await ref.read(myBlockedUidsProvider.future).catchError((_) => <String>[]);
      final friendUids = await ref.read(myFriendUidsProvider.future).catchError((_) => <String>[]);

      final result = await ref.read(feedRepoProvider).fetchFeedPage(
        mainType: state.selectMainType,
        subType: state.selectSubType,
        onlyFriendFeeds: state.onlyFriendFeeds,
        blockedUids: blockedUids,
        friendUids: friendUids,
        pageSize: _pageSize,
      );

      // 🔥 [핵심 추가] 데이터 로딩이 끝난 후 컨트롤러가 살아있는지 검사!
      if (!mounted) return;

      state = state.copyWith(
        isLoading: false,
        items: result.items,
        lastDoc: result.lastDoc,
        hasMore: result.hasMore,
      );
    } catch (_) {
      // 🔥 [핵심 추가] 에러가 났을 때도 동일하게 검사
      if (!mounted) return;
      state = state.copyWith(isLoading: false, hasMore: false);
    }
  }

  Future<void> fetchNextPage() async {
    if (state.isLoading || state.isLoadingMore || !state.hasMore) return;
    if (state.lastDoc == null) return;

    state = state.copyWith(isLoadingMore: true);

    try {
      final blockedUids = await ref.read(myBlockedUidsProvider.future).catchError((_) => <String>[]);
      final friendUids = await ref.read(myFriendUidsProvider.future).catchError((_) => <String>[]);

      final result = await ref.read(feedRepoProvider).fetchFeedPage(
        mainType: state.selectMainType,
        subType: state.selectSubType,
        onlyFriendFeeds: state.onlyFriendFeeds,
        blockedUids: blockedUids,
        friendUids: friendUids,
        pageSize: _pageSize,
        startAfter: state.lastDoc,
      );

      // 🔥 [핵심 추가]
      if (!mounted) return;

      state = state.copyWith(
        isLoadingMore: false,
        items: [...state.items, ...result.items],
        lastDoc: result.lastDoc,
        hasMore: result.hasMore,
      );
    } catch (_) {
      // 🔥 [핵심 추가]
      if (!mounted) return;
      state = state.copyWith(isLoadingMore: false);
    }
  }
}