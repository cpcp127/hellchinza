import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_pagination/firebase_pagination.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hellchinza/common/common_chip.dart';
import 'package:hellchinza/constants/app_constants.dart';
import 'package:hellchinza/feed/feed_list/feed_list_controller.dart';
import 'package:hellchinza/feed/feed_list/feed_list_state.dart';

import '../../common/common_feed_card.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_text_style.dart';
import '../domain/feed_model.dart';

final myFriendUidsProvider = FutureProvider<List<String>>((ref) async {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return const [];

  final snap = await FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .collection('friends')
      .get();

  // 문서 id가 friend uid 라면 이게 제일 깔끔
  return snap.docs.map((d) => d.id).toList();
});

class FeedListView extends ConsumerStatefulWidget {
  const FeedListView({super.key});

  @override
  ConsumerState createState() => _FeedListViewState();
}

class _FeedListViewState extends ConsumerState<FeedListView>
    with SingleTickerProviderStateMixin {
  late TabController tabController;
  final List<String> feedMainTabLabels = [
    '전체',
    ...FeedMainType.values.map((e) => e.label),
  ];

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(feedListControllerProvider);
    final controller = ref.read(feedListControllerProvider.notifier);
    return SafeArea(
      child: Column(
        children: [
          _buildMainTabBar(),
          SizedBox(height: 8),
          state.selectMainType == '식단' ? Container() : _buildSubListView(),
          SizedBox(height: 8),
          _buildFriendOnlySwitch(controller, state),
          SizedBox(height: 8),
          Expanded(child: _buildFeedPaginationList()),
        ],
      ),
    );
  }

  Padding _buildSubListView() {
    final state = ref.watch(feedListControllerProvider);
    final controller = ref.read(feedListControllerProvider.notifier);
    return Padding(
      padding: const EdgeInsets.only(left: 10),
      child: Container(
        height: 40,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: workList.length + 1, // ⭐ +1
          itemBuilder: (context, index) {
            final String label = index == 0 ? '전체' : workList[index - 1];
            return Padding(
              padding: const EdgeInsets.only(right: 4),
              child: CommonChip(
                label: label,
                selected: label == state.selectSubType,
                onTap: () {
                  controller.onChangeSubType(label);
                },
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildFriendOnlySwitch(
    FeedListController controller,
    FeedListState state,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            '친구 피드만',
            style: AppTextStyle.labelMediumStyle.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(width: 8),
          CupertinoSwitch(
            value: state.onlyFriendFeeds,
            onChanged: (on) => controller.toggleOnlyFriendFeeds(on),
          ),
        ],
      ),
    );
  }

  Widget _buildMainTabBar() {
    final state = ref.watch(feedListControllerProvider);
    final controller = ref.read(feedListControllerProvider.notifier);
    return Container(
      height: 56,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.white, // gray50
      ),
      child: TabBar(
        controller: tabController,
        isScrollable: false,
        // 4등분 고정 느낌
        dividerColor: Colors.transparent,
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: BoxDecoration(
          color: AppColors.bgWhite,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.borderSecondary, width: 1),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0F000000),
              blurRadius: 10,
              offset: Offset(0, 2),
            ),
          ],
        ),
        labelColor: AppColors.textDefault,
        // gray900
        unselectedLabelColor: AppColors.textSecondary,
        // gray700
        labelStyle: AppTextStyle.titleSmallBoldStyle,
        // 14, w700
        unselectedLabelStyle: AppTextStyle.titleSmallMediumStyle,
        // 14, w500
        tabs: feedMainTabLabels.map((label) => Tab(text: label)).toList(),
        onTap: (index) {
          controller.onChangeMainType(feedMainTabLabels[index]);
        },
      ),
    );
  }

  Widget _buildFeedPaginationList() {
    final state = ref.watch(feedListControllerProvider);
    final controller = ref.read(feedListControllerProvider.notifier);
    // final query = controller.buildFeedQuery();
    final friendsAsync = ref.watch(myFriendUidsProvider);
    return friendsAsync.when(
      data: (friendUids) {
        final query = controller.buildFeedQuery(friendUids: friendUids);
        final friendSet = friendUids.toSet();

        final bool needClientFilter =
            state.onlyFriendFeeds && friendUids.length > 10;

        return RefreshIndicator(
          color: AppColors.sky400,
          backgroundColor: AppColors.bgWhite,
          onRefresh: () async {
            ref.read(feedListControllerProvider.notifier).refresh();

            // RefreshIndicator가 너무 빨리 끝나면 UX가 이상해서 짧게 딜레이(선택)
            await Future.delayed(const Duration(milliseconds: 250));
          },
          child: FirestorePagination(
            key: ValueKey(
              '${state.selectMainType}_${state.selectSubType}_${state.refreshTick}',
            ),
            // ⭐️ 중요: 필터 바뀌면 리셋
            query: query,
            limit: 10,
            viewType: ViewType.list,
            separatorBuilder: (context, index) => const SizedBox(height: 12),

            itemBuilder: (context, docs, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;
              final authorUid = (data['authorUid'] ?? '').toString();
              if (needClientFilter && !friendSet.contains(authorUid)) {
                return const SizedBox.shrink(); // ✅ 친구 아니면 숨김
              }
              final feed = FeedModel.fromJson(data);
              return FeedCard(feed: feed);
            },

            onEmpty: Center(
              child: Padding(
                padding: const EdgeInsets.only(top: 40),
                child: Text(
                  state.onlyFriendFeeds ? '아직 친구의 피드가 없어요' : '아직 피드가 없어요',
                  style: AppTextStyle.bodyMediumStyle.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ),

            bottomLoader: const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
        );
      },
      error: (e, _) => Container(),
      loading: () => const Center(child: CupertinoActivityIndicator()),
    );
  }

  @override
  void initState() {
    super.initState();
    tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    tabController.dispose();
    super.dispose();
  }
}
