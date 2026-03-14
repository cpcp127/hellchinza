import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_pagination/firebase_pagination.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hellchinza/common/common_banner_ad.dart';
import 'package:hellchinza/constants/app_constants.dart';
import 'package:hellchinza/feed/feed_list/feed_list_controller.dart';

import '../../common/common_feed_card.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_text_style.dart';
import '../domain/feed_model.dart';
import '../widget/feed_filter_sheet.dart';

class FeedListView extends ConsumerStatefulWidget {
  const FeedListView({super.key});

  @override
  ConsumerState createState() => _FeedListViewState();
}

class _FeedListViewState extends ConsumerState<FeedListView>
    with SingleTickerProviderStateMixin {

  final ScrollController _feedScrollCtrl = ScrollController();

  final List<FeedModel> _feedItems = [];
  DocumentSnapshot<Map<String, dynamic>>? _feedCursor;

  bool _feedIsLoading = false; // 첫 로딩/추가 로딩 공용
  bool _feedIsLoadingMore = false; // 하단 로딩 표시용
  bool _feedHasMore = true;

  // ✅ 필터 키(필터 바뀌면 전체 리셋)
  String? _feedQueryKey;

  @override
  void initState() {
    super.initState();

    _feedScrollCtrl.addListener(() {
      // 바닥 근처 도달하면 다음 페이지 로드
      if (_feedScrollCtrl.position.pixels >=
          _feedScrollCtrl.position.maxScrollExtent - 300) {
        _fetchNextFeedPage();
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _resetAndFetchFeeds(); // 최초 1페이지
    });
  }

  @override
  void dispose() {
    _feedScrollCtrl.dispose();
    super.dispose();
  }

  String _makeFeedQueryKey() {
    final s = ref.read(feedListControllerProvider);
    // ✅ 너가 쓰는 key 규칙 그대로 유지
    return '${s.selectMainType}_${s.selectSubType}_${s.refreshTick}_${s.onlyFriendFeeds}';
  }

  Future<void> _resetAndFetchFeeds() async {
    if (_feedIsLoading) return;

    setState(() {
      _feedIsLoading = true;
      _feedIsLoadingMore = false;
      _feedHasMore = true;
      _feedCursor = null;
      _feedItems.clear();
    });

    try {
      final controller = ref.read(feedListControllerProvider.notifier);

      // ✅ 1페이지 쿼리
      final baseQuery = controller.buildFeedQuery().limit(10);

      final snap = await baseQuery.get();
      final docs = snap.docs;

      final items = docs.map((d) => FeedModel.fromJson(d.data())).toList();

      setState(() {
        _feedItems.addAll(items);
        _feedCursor = docs.isNotEmpty ? docs.last : null;
        _feedHasMore = docs.length == 10; // limit보다 적으면 끝
        _feedIsLoading = false;
      });
    } catch (e) {
      setState(() {
        _feedIsLoading = false;
        _feedHasMore = false;
      });
    }
  }

  Future<void> _fetchNextFeedPage() async {
    if (_feedIsLoading || _feedIsLoadingMore || !_feedHasMore) return;
    if (_feedCursor == null) return;

    setState(() => _feedIsLoadingMore = true);

    try {
      final controller = ref.read(feedListControllerProvider.notifier);

      final q = controller
          .buildFeedQuery()
          .startAfterDocument(_feedCursor!)
          .limit(10);

      final snap = await q.get();
      final docs = snap.docs;

      final items = docs.map((d) => FeedModel.fromJson(d.data())).toList();

      setState(() {
        _feedItems.addAll(items);
        _feedCursor = docs.isNotEmpty ? docs.last : _feedCursor;
        _feedHasMore = docs.length == 10;
        _feedIsLoadingMore = false;
      });
    } catch (_) {
      setState(() => _feedIsLoadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(feedListControllerProvider);
    final controller = ref.read(feedListControllerProvider.notifier);
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _buildFilterButton(context, ref),
          ),
          SizedBox(height: 8),
          Expanded(child: _buildFeedPaginationList()),
          CommonBannerAd(),
        ],
      ),
    );
  }

  Widget _buildFilterButton(BuildContext context, WidgetRef ref) {
    final state = ref.watch(feedListControllerProvider);
    final controller = ref.read(feedListControllerProvider.notifier);

    final label = [
      state.selectMainType,
      if (state.selectMainType != '식단') state.selectSubType,
      if (state.onlyFriendFeeds) '친구만',
    ].join(' · ');

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () async {
        await showGeneralDialog(
          context: context,
          barrierLabel: 'feed_filter',
          barrierDismissible: true,
          barrierColor: Colors.black.withOpacity(0.55),
          transitionDuration: const Duration(milliseconds: 220),
          pageBuilder: (_, __, ___) {
            return FeedFilterWheelSheet(
              initialMainType: state.selectMainType,
              initialSubType: state.selectSubType,
              initialOnlyFriends: state.onlyFriendFeeds,
              onApply: (main, sub, onlyFriends) {
                controller.applyFilters(
                  mainType: main,
                  subType: sub,
                  onlyFriends: onlyFriends,
                );
              },
            );
          },
          transitionBuilder: (context, animation, secondaryAnimation, child) {
            final curved = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            );

            return FadeTransition(
              opacity: curved,
              child: child,
            );
          },
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.bgWhite,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.borderSecondary),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.tune, size: 18, color: AppColors.icDefault),
            const SizedBox(width: 8),
            Text(
              label,
              style: AppTextStyle.labelMediumStyle.copyWith(
                color: AppColors.textDefault,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.expand_more, color: AppColors.icSecondary),
          ],
        ),
      ),
    );
  }

  Widget _buildFeedPaginationList() {
    final state = ref.watch(feedListControllerProvider);
    final controller = ref.read(feedListControllerProvider.notifier);

    // ✅ 필터/refreshTick 바뀌면 자동으로 리스트 리셋
    final newKey = _makeFeedQueryKey();
    if (_feedQueryKey != newKey) {
      _feedQueryKey = newKey;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _resetAndFetchFeeds();
      });
    }

    return RefreshIndicator(
      color: AppColors.sky400,
      backgroundColor: AppColors.bgWhite,
      onRefresh: () async {
        controller.refresh(); // ✅ 너 기존 refresh 유지
        await _resetAndFetchFeeds();

        // UX 딜레이(너 기존 유지)
        await Future.delayed(const Duration(milliseconds: 250));
      },
      child: _feedIsLoading
          ? const Center(child: CircularProgressIndicator())
          : _feedItems.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                const SizedBox(height: 80),
                Center(
                  child: Text(
                    state.onlyFriendFeeds ? '아직 친구의 피드가 없어요' : '아직 피드가 없어요',
                    style: AppTextStyle.bodyMediumStyle.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            )
          : ListView.separated(
              controller: _feedScrollCtrl,

              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: _feedItems.length + 1,
              // ✅ 마지막: 로더/끝 표시
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                if (index < _feedItems.length) {
                  final feed = _feedItems[index];
                  return FeedCard(feedId: feed.id);
                }

                // ✅ 마지막 줄: 더 불러오는 중/끝
                if (_feedIsLoadingMore) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                if (!_feedHasMore) {
                  return const SizedBox(height: 6);
                }

                // ✅ 아직 더 가져올 수 있는데 로딩이 안 돌고 있으면(스크롤로 트리거)
                return const SizedBox(height: 6);
              },
            ),
    );
  }
}
