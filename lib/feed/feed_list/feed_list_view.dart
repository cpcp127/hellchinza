import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../common/common_banner_ad.dart';
import '../../../common/common_feed_card.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_text_style.dart';
import '../../../meet/widget/empty_meet_list.dart';
import '../create_feed/create_feed_view.dart';
import '../providers/feed_provider.dart';
import '../widget/feed_filter_sheet.dart';

class FeedListView extends ConsumerStatefulWidget {
  const FeedListView({super.key});

  @override
  ConsumerState<FeedListView> createState() => _FeedListViewState();
}

class _FeedListViewState extends ConsumerState<FeedListView> {
  final ScrollController _feedScrollCtrl = ScrollController();
  String? _feedQueryKey;

  @override
  void initState() {
    super.initState();

    _feedScrollCtrl.addListener(() {
      if (_feedScrollCtrl.position.pixels >=
          _feedScrollCtrl.position.maxScrollExtent - 300) {
        final blockedUids =
            ref.read(myBlockedUidsProvider).value ?? const <String>[];
        final friendUids =
            ref.read(myFriendUidsProvider).value ?? const <String>[];

        ref
            .read(feedListControllerProvider.notifier)
            .fetchNextPage(blockedUids: blockedUids, friendUids: friendUids);
      }
    });
  }

  @override
  void dispose() {
    _feedScrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(feedListControllerProvider);
    final controller = ref.read(feedListControllerProvider.notifier);
    final blockedUidsAsync = ref.watch(myBlockedUidsProvider);
    final friendUidsAsync = ref.watch(myFriendUidsProvider);

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _buildFilterButton(context),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: blockedUidsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => const Center(child: Text('차단 목록을 불러오지 못했어요')),
              data: (blockedUids) {
                return friendUidsAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (_, __) =>
                      const Center(child: Text('친구 목록을 불러오지 못했어요')),
                  data: (friendUids) {
                    final newKey = controller.makeQueryKey(
                      blockedUids: blockedUids,
                      friendUids: friendUids,
                    );

                    if (_feedQueryKey != newKey) {
                      _feedQueryKey = newKey;
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        ref
                            .read(feedListControllerProvider.notifier)
                            .resetAndFetch(
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
                        await controller.resetAndFetch(
                          blockedUids: blockedUids,
                          friendUids: friendUids,
                        );
                        await Future.delayed(const Duration(milliseconds: 250));
                      },
                      child: state.isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : state.items.isEmpty
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
                                    builder: (_) => const CreateFeedView(),
                                  ),
                                );
                              },
                            )
                          : ListView.separated(
                              controller: _feedScrollCtrl,
                              physics: const AlwaysScrollableScrollPhysics(),
                              itemCount: state.items.length + 1,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                if (index < state.items.length) {
                                  final feed = state.items[index];
                                  return FeedCard(feedId: feed.id);
                                }

                                if (state.isLoadingMore) {
                                  return const Padding(
                                    padding: EdgeInsets.all(16),
                                    child: Center(
                                      child: CircularProgressIndicator(),
                                    ),
                                  );
                                }

                                return const SizedBox(height: 6);
                              },
                            ),
                    );
                  },
                );
              },
            ),
          ),
          // google admob 나중에
          // const CommonBannerAd(),
        ],
      ),
    );
  }

  Widget _buildFilterButton(BuildContext context) {
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
}
