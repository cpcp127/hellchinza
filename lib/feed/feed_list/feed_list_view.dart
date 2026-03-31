import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

  @override
  void initState() {
    super.initState();

    // 화면이 처음 생성될 때 딱 1번만 초기 데이터를 불러옵니다.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(feedListControllerProvider.notifier).resetAndFetch();
    });

    _feedScrollCtrl.addListener(() {
      if (_feedScrollCtrl.position.pixels >=
          _feedScrollCtrl.position.maxScrollExtent - 300) {
        // 파라미터 전달 없이 컨트롤러에게 다음 페이지 요청만 던집니다.
        ref.read(feedListControllerProvider.notifier).fetchNextPage();
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

    // 🔥 [추가된 부분 1] Provider를 watch하여 메모리에서 날아가지 않게(AutoDispose) 생명줄을 잡아둡니다.
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
            // 🔥 [추가된 부분 2] 차단/친구 목록이 로딩 중일 때는 컨트롤러가 터지지 않게 뷰에서 미리 로딩을 돌려줍니다.
            child: (blockedUidsAsync.isLoading || friendUidsAsync.isLoading)
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
              color: AppColors.sky400,
              backgroundColor: AppColors.bgWhite,
              onRefresh: () async {
                await controller.resetAndFetch();
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
            ),
          ),
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
      // (기존 필터 버튼 UI 코드와 완전히 동일합니다)
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
                // 필터 적용 로직만 호출합니다. (초기화는 컨트롤러 내부에서 처리)
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
