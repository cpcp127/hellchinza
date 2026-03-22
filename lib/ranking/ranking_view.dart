import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_pagination/firebase_pagination.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hellchinza/auth/domain/user_model.dart';
import 'package:hellchinza/common/common_profile_avatar.dart';
import 'package:hellchinza/constants/app_colors.dart';
import 'package:hellchinza/constants/app_text_style.dart';

import 'ranking_controller.dart';

class RankingView extends ConsumerWidget {
  const RankingView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(rankingControllerProvider);
    final controller = ref.read(rankingControllerProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.bgWhite,
      appBar: AppBar(
        backgroundColor: AppColors.bgWhite,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text('운동 랭킹'),
        actions: [
          TextButton(
            onPressed: () {
              _showScoreGuideSheet(context);
            },
            child: Text(
              '점수 기준',
              style: AppTextStyle.labelMediumStyle.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.sky400,
        backgroundColor: AppColors.bgWhite,
        onRefresh: () => controller.init(),
        child: state.isLoading
            ? const Center(child: CircularProgressIndicator())
            : state.errorMessage != null
            ? Center(
                child: Text(
                  state.errorMessage!,
                  style: AppTextStyle.bodyMediumStyle.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  _MyRankingSummaryCard(
                    weeklyScore: state.myWeeklyScore,
                    topPercent: state.topPercent,
                  ),
                  const SizedBox(height: 16),
                  _Top3Section(users: state.top3),
                  const SizedBox(height: 20),
                  Text('전체 순위', style: AppTextStyle.titleMediumBoldStyle),
                  const SizedBox(height: 12),

                  FirestorePagination(
                    key: ValueKey(state.top3.map((e) => e.uid).join(',')),
                    query: controller.buildRestQuery(),
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemBuilder:
                        (
                          BuildContext context,
                          List<DocumentSnapshot<Object?>> docs,
                          int index,
                        ) {
                          final doc = docs[index];
                          final data = doc.data() as Map<String, dynamic>;
                          final user = UserModel.fromFirestore(data);

                          final rank = index + 4;

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _RankingListItem(rank: rank, user: user),
                          );
                        },
                    onEmpty: Center(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 40),
                        child: Text(
                          '아직 랭킹 데이터가 없어요',
                          style: AppTextStyle.bodyMediumStyle.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Future<void> _showScoreGuideSheet(BuildContext context) async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) {
        return const _ScoreGuideSheet();
      },
    );
  }


}

class _Top3Section extends StatelessWidget {
  const _Top3Section({required this.users});

  final List<UserModel> users;

  @override
  Widget build(BuildContext context) {
    final first = users.length > 0 ? users[0] : null;
    final second = users.length > 1 ? users[1] : null;
    final third = users.length > 2 ? users[2] : null;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: second == null
              ? const SizedBox()
              : _TopRankCard(rank: 2, user: second, height: 172),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: first == null
              ? const SizedBox()
              : _TopRankCard(
                  rank: 1,
                  user: first,
                  height: 208,
                  highlight: true,
                ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: third == null
              ? const SizedBox()
              : _TopRankCard(rank: 3, user: third, height: 172),
        ),
      ],
    );
  }
}

class _TopRankCard extends StatelessWidget {
  const _TopRankCard({
    required this.rank,
    required this.user,
    required this.height,
    this.highlight = false,
  });

  final int rank;
  final UserModel user;
  final double height;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final bgColor = highlight ? AppColors.sky50 : AppColors.bgSecondary;
    final borderColor = highlight
        ? AppColors.borderPrimary
        : AppColors.borderSecondary;

    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 350 + (rank * 80)),
      tween: Tween(begin: 0, end: 1),
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 18 * (1 - value)),
          child: Opacity(opacity: value, child: child),
        );
      },
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          Container(
            height: height,
            padding: const EdgeInsets.fromLTRB(12, 22, 12, 14),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CommonProfileAvatar(
                  imageUrl: user.photoUrl,
                  size: highlight ? 72 : 60,
                  gender: user.gender,
                  uid: user.uid,lastWeeklyRank: user.lastWeeklyRank,
                ),
                const SizedBox(height: 12),
                Text(
                  user.nickname,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: AppTextStyle.titleSmallBoldStyle.copyWith(
                    color: AppColors.textDefault,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${user.scoreWeekly}점',
                  style: AppTextStyle.titleSmallBoldStyle.copyWith(
                    color: AppColors.sky400,
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: -10,
            child: Container(
              width: highlight ? 36 : 30,
              height: highlight ? 36 : 30,
              decoration: BoxDecoration(
                color: highlight ? Colors.amber : AppColors.gray300,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.bgWhite, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Text(
                '$rank',
                style: AppTextStyle.titleSmallBoldStyle.copyWith(
                  color: highlight ? AppColors.white : AppColors.textDefault,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RankingListItem extends StatelessWidget {
  const _RankingListItem({required this.rank, required this.user});

  final int rank;
  final UserModel user;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.bgWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderSecondary),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 32,
            child: Text(
              '$rank',
              style: AppTextStyle.titleSmallBoldStyle.copyWith(
                color: AppColors.textDefault,
              ),
            ),
          ),
          const SizedBox(width: 10),
          CommonProfileAvatar(
            imageUrl: user.photoUrl,
            gender: user.gender,
            size: 42,
            uid: user.uid,lastWeeklyRank: user.lastWeeklyRank,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              user.nickname,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyle.titleSmallBoldStyle.copyWith(
                color: AppColors.textDefault,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '${user.scoreWeekly}점',
            style: AppTextStyle.titleSmallBoldStyle.copyWith(
              color: AppColors.sky400,
            ),
          ),
        ],
      ),
    );
  }
}
class _ScoreGuideSheet extends StatelessWidget {
  const _ScoreGuideSheet();

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + bottom),
      decoration: const BoxDecoration(
        color: AppColors.bgWhite,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [

          const SizedBox(height: 24),

          Row(
            children: [
              Text(
                '점수 올리는 방법',
                style: AppTextStyle.titleMediumBoldStyle.copyWith(
                  color: AppColors.textDefault,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(
                  Icons.close,
                  color: AppColors.icDefault,
                ),
              ),
            ],
          ),

          const SizedBox(height: 4),

          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '꾸준한 운동과 건강한 활동에 점수를 드려요',
              style: AppTextStyle.bodySmallStyle.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),

          const SizedBox(height: 18),

          Flexible(
            child: SingleChildScrollView(
              child: Column(
                children: const [
                  _ScoreGuideItem(
                    title: '오운완 피드 작성',
                    pointText: '+20점',
                    desc: '하루 1회만 인정돼요',
                  ),
                  _ScoreGuideItem(
                    title: '일반 피드 작성',
                    pointText: '+5점',
                    desc: '하루 최대 3회까지 인정돼요',
                  ),
                  _ScoreGuideItem(
                    title: '모임 참가',
                    pointText: '+10점',
                    desc: '같은 모임은 최초 1회만 인정돼요',
                  ),
                  _ScoreGuideItem(
                    title: '번개 참가',
                    pointText: '+15점',
                    desc: '같은 번개는 최초 1회만 인정돼요',
                  ),
                  _ScoreGuideItem(
                    title: '모임 생성',
                    pointText: '+20점',
                    desc: '모임 생성 시 1회 지급돼요',
                  ),
                  _ScoreGuideItem(
                    title: '번개 생성',
                    pointText: '+15점',
                    desc: '번개 생성 시 1회 지급돼요',
                  ),
                  _ScoreGuideItem(
                    title: '댓글 작성',
                    pointText: '+2점',
                    desc: '하루 최대 10회까지 인정돼요',
                  ),
                  _ScoreGuideItem(
                    title: '좋아요 받기',
                    pointText: '+1점',
                    desc: '피드당 최대 20점까지 쌓여요',
                  ),
                  _ScoreGuideItem(
                    title: '댓글 받기',
                    pointText: '+2점',
                    desc: '피드당 최대 20점까지 쌓여요',
                  ),
                  _ScoreGuideItem(
                    title: '주간 목표 달성',
                    pointText: '목표일수 × 10점',
                    desc: '예: 목표 4일 달성 시 +40점',
                    highlight: true,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScoreGuideItem extends StatelessWidget {
  const _ScoreGuideItem({
    required this.title,
    required this.pointText,
    required this.desc,
    this.highlight = false,
  });

  final String title;
  final String pointText;
  final String desc;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: highlight ? AppColors.sky50 : AppColors.bgSecondary,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: highlight
              ? AppColors.borderPrimary
              : AppColors.borderSecondary,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyle.titleSmallBoldStyle.copyWith(
                    color: AppColors.textDefault,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  desc,
                  style: AppTextStyle.bodySmallStyle.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: highlight ? AppColors.sky50 : AppColors.bgWhite,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: highlight
                    ? AppColors.borderPrimary
                    : AppColors.borderSecondary,
              ),
            ),
            child: Text(
              pointText,
              style: AppTextStyle.labelSmallStyle.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MyRankingSummaryCard extends StatelessWidget {
  const _MyRankingSummaryCard({
    required this.weeklyScore,
    required this.topPercent,
  });

  final int weeklyScore;
  final double? topPercent;

  @override
  Widget build(BuildContext context) {
    final percentText = topPercent == null
        ? '-'
        : topPercent! < 1
        ? '1%'
        : topPercent!.ceil().toString();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      // decoration: BoxDecoration(
      //   color: AppColors.sky50,
      //   borderRadius: BorderRadius.circular(20),
      //   border: Border.all(color: AppColors.borderPrimary),
      // ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            '내 이번 주 기록',
            style: AppTextStyle.titleMediumBoldStyle.copyWith(
              color: AppColors.textDefault,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${weeklyScore}점',
            style: AppTextStyle.headlineSmallBoldStyle.copyWith(
              color: AppColors.sky400,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '상위 $percentText%',
            style: AppTextStyle.headlineSmallBoldStyle.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}