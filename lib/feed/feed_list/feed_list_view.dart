import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_pagination/firebase_pagination.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hellchinza/common/common_banner_ad.dart';
import 'package:hellchinza/constants/app_constants.dart';
import 'package:hellchinza/feed/create_feed/create_feed_view.dart';
import 'package:hellchinza/feed/feed_list/feed_list_controller.dart';

import '../../common/common_feed_card.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_text_style.dart';
import '../../meet/widget/empty_meet_list.dart';
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
      if (_feedScrollCtrl.position.pixels >=
          _feedScrollCtrl.position.maxScrollExtent - 300) {
        final blockedUids = ref
            .read(myBlockedUidsProvider)
            .value ?? const [];
        final friendUids = ref
            .read(myFriendUidsProvider)
            .value ?? const [];

        _fetchNextFeedPage(
          blockedUids: blockedUids,
          friendUids: friendUids,
        );
      }
    });
  }

  @override
  void dispose() {
    _feedScrollCtrl.dispose();
    super.dispose();
  }

  String _makeFeedQueryKey({
    required List<String> blockedUids,
    required List<String> friendUids,
  }) {
    final s = ref.read(feedListControllerProvider);
    final sortedBlocked = [...blockedUids]..sort();
    final sortedFriends = [...friendUids]..sort();

    return '${s.selectMainType}_${s.selectSubType}_${s.refreshTick}_${s
        .onlyFriendFeeds}_${sortedBlocked.join(",")}_${sortedFriends.join(
        ",")}';
  }

  Future<void> _resetAndFetchFeeds({
    required List<String> blockedUids, required List<String> friendUids,
  }) async {
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
      final blockedSet = blockedUids.toSet();
      final friendSet = friendUids.toSet();
      final myUid = FirebaseAuth.instance.currentUser?.uid ?? '';

      const pageSize = 10;
      final List<FeedModel> visibleItems = [];
      DocumentSnapshot<Map<String, dynamic>>? cursor;
      bool hasMore = true;

      while (visibleItems.length < pageSize && hasMore) {
        Query<Map<String, dynamic>> query =
        controller.buildFeedQuery().limit(pageSize * 2);

        if (cursor != null) {
          query = query.startAfterDocument(cursor);
        }

        final snap = await query.get();
        final docs = snap.docs;

        if (docs.isEmpty) {
          hasMore = false;
          break;
        }

        cursor = docs.last;

        for (final d in docs) {
          final data = d.data();

          final canView = controller.canViewFeed(
            data: data,
            myUid: myUid,
            blockedUidSet: blockedSet,
            friendUidSet: friendSet,
          );

          if (!canView) continue;

          try {
            visibleItems.add(FeedModel.fromJson(data));
          } catch (_) {}

          if (visibleItems.length >= pageSize) {
            break;
          }
        }

        if (docs.length < pageSize * 2) {
          hasMore = false;
        }
      }

      setState(() {
        _feedItems.addAll(visibleItems);
        _feedCursor = cursor;
        _feedHasMore = hasMore;
        _feedIsLoading = false;
      });
    } catch (e) {
      setState(() {
        _feedIsLoading = false;
        _feedHasMore = false;
      });
    }
  }

  Future<void> _fetchNextFeedPage({
    required List<String> blockedUids, required List<String> friendUids,
  }) async {
    if (_feedIsLoading || _feedIsLoadingMore || !_feedHasMore) return;
    if (_feedCursor == null) return;

    setState(() => _feedIsLoadingMore = true);

    try {
      final controller = ref.read(feedListControllerProvider.notifier);
      final blockedSet = blockedUids.toSet();
      final friendSet = friendUids.toSet();
      final myUid = FirebaseAuth.instance.currentUser?.uid ?? '';

      const pageSize = 10;
      final List<FeedModel> visibleItems = [];
      DocumentSnapshot<Map<String, dynamic>>? cursor = _feedCursor;
      bool hasMore = true;

      while (visibleItems.length < pageSize && hasMore) {
        if (cursor == null) {
          hasMore = false;
          break;
        }

        final q = controller
            .buildFeedQuery()
            .startAfterDocument(cursor)
            .limit(pageSize * 2);

        final snap = await q.get();
        final docs = snap.docs;

        if (docs.isEmpty) {
          hasMore = false;
          break;
        }

        cursor = docs.last;

        for (final d in docs) {
          final data = d.data();

          final canView = controller.canViewFeed(
            data: data,
            myUid: myUid,
            blockedUidSet: blockedSet,
            friendUidSet: friendSet,
          );

          if (!canView) continue;

          try {
            visibleItems.add(FeedModel.fromJson(data));
          } catch (_) {}

          if (visibleItems.length >= pageSize) {
            break;
          }
        }

        if (docs.length < pageSize * 2) {
          hasMore = false;
        }
      }

      setState(() {
        _feedItems.addAll(visibleItems);
        _feedCursor = cursor;
        _feedHasMore = hasMore;
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

            return FadeTransition(opacity: curved, child: child);
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
    final blockedUidsAsync = ref.watch(myBlockedUidsProvider);
    final friendUidsAsync = ref.watch(myFriendUidsProvider);
    return blockedUidsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => const Center(child: Text('차단 목록을 불러오지 못했어요')),
      data: (blockedUids) {
        return friendUidsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => const Center(child: Text('친구 목록을 불러오지 못했어요')),
          data: (friendUids) {
            final newKey = _makeFeedQueryKey(
              blockedUids: blockedUids,
              friendUids: friendUids,
            );

            if (_feedQueryKey != newKey) {
              _feedQueryKey = newKey;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _resetAndFetchFeeds(
                  blockedUids: blockedUids,
                  friendUids: friendUids,
                );
              });
            }

            return RefreshIndicator(
              color: AppColors.sky400,
              backgroundColor: AppColors.bgWhite,
              onRefresh: () async {
                controller.refresh();
                await _resetAndFetchFeeds(
                  blockedUids: blockedUids,
                  friendUids: friendUids,
                );
                await Future.delayed(const Duration(milliseconds: 250));
              },
              child: _feedIsLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _feedItems.isEmpty
                  ? EmptyList(
                icon: Icons.feed_outlined,
                btnTitle: '피드 작성하기',
                title: '아직 피드가 없어요',
                subTitle: '피드로 첫 운동기록을 작성해볼까요?',
                onTapCreate: () {
                  Navigator.push(
                    context,
                    CupertinoPageRoute(
                      fullscreenDialog: true,
                      builder: (_) => CreateFeedView(),
                    ),
                  );
                },
              )
                  : ListView.separated(
                controller: _feedScrollCtrl,
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: _feedItems.length + 1,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  if (index < _feedItems.length) {
                    final feed = _feedItems[index];
                    return FeedCard(feedId: feed.id);
                  }

                  if (_feedIsLoadingMore) {
                    return const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }

                  if (!_feedHasMore) {
                    return const SizedBox(height: 6);
                  }

                  return const SizedBox(height: 6);
                },
              ),
            );
          },
        );
      },
    );
  }
}
