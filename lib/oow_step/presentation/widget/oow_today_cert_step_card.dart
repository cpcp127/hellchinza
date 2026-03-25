import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:hellchinza/common/common_network_image.dart';
import 'package:hellchinza/feed/feed_detail/feed_detail_view.dart';

import '../../../../../constants/app_colors.dart';
import '../../../../../constants/app_text_style.dart';
import '../../../feed/create_feed/create_feed_view.dart';
import '../../providers/oow_provider.dart';
import '../oow_step_state.dart';
import 'oow_step_shell.dart';

class OowTodayCertStepPage extends ConsumerWidget {
  const OowTodayCertStepPage({
    super.key,
    required this.uid,
  });

  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(oowStepControllerProvider(uid));

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final todayFeeds = state.weekMap[_dateKey(today)] ?? const [];
    final hasTodayFeed = todayFeeds.isNotEmpty;
    final latestFeed = hasTodayFeed ? todayFeeds.first : null;
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    final isMine = myUid == uid;
    return OowStepShell(
      step: 1,
      title: '오늘 오운완 인증',
      subTitle: hasTodayFeed
          ? '오늘 인증한 오운완 피드를 확인해보세요'
          : '오늘 운동을 마쳤다면 지금 오운완을 인증해보세요',
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 280),
        child: hasTodayFeed
            ? _CompletedTodayCertification(
          key: const ValueKey('completed'),
          item: latestFeed!,
        )
            :  _EmptyTodayCertification(
          key: ValueKey('empty'),isMine: isMine,
        ),
      ),
    );
  }

  String _dateKey(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    return '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }
}

class _CompletedTodayCertification extends StatelessWidget {
  const _CompletedTodayCertification({
    super.key,
    required this.item,
  });

  final OowFeedItem item;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: key,
      children: [
        Expanded(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) {
              return Opacity(
                opacity: value,
                child: Transform.translate(
                  offset: Offset(0, 18 * (1 - value)),
                  child: child,
                ),
              );
            },
            child: OowTodayFeedHeroCard(
              item: item,
              onTap: () {
                Navigator.push(
                  context,
                  CupertinoPageRoute(
                    fullscreenDialog: true,
                    builder: (_) => FeedDetailView(feedId: item.id),
                  ),
                );
              },
            ),
          ),
        ),

      ],
    );
  }
}

class _EmptyTodayCertification extends StatelessWidget {
  const _EmptyTodayCertification({
    super.key,
    required this.isMine,
  });

  final bool isMine;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        key: key,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: AppColors.sky50,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.borderSecondary),
              ),
              alignment: Alignment.center,
              child: const Icon(
                CupertinoIcons.flame_fill,
                size: 32,
                color: AppColors.btnPrimary,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              isMine ? '아직 오늘의 운동 인증이 없어요' : '오늘은 아직 운동 인증이 없어요',
              style: AppTextStyle.titleMediumBoldStyle,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              isMine
                  ? '운동을 마쳤다면 오운완을 인증해보세요'
                  : '조금 뒤 다시 확인해보세요',
              style: AppTextStyle.bodyMediumStyle.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            if (isMine) ...[
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      CupertinoPageRoute(
                        fullscreenDialog: true,
                        builder: (_) => const CreateFeedView(
                          isOowEntry: true,
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.btnPrimary,
                    foregroundColor: AppColors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: Text(
                    '오운완 인증하기',
                    style: AppTextStyle.titleSmallBoldStyle.copyWith(
                      color: AppColors.white,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class OowTodayFeedHeroCard extends StatelessWidget {
  const OowTodayFeedHeroCard({
    super.key,
    required this.item,
    this.onTap,
  });

  final OowFeedItem item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final hasImage = item.imageUrls.isNotEmpty;
    final imageUrl = hasImage ? item.imageUrls.first : '';
    final title = item.text.trim().isEmpty ? '오늘의 오운완 기록' : item.text.trim();
    final typeText = item.subType.trim().isEmpty ? '운동 기록' : item.subType.trim();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.bgWhite,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: AppColors.borderSecondary),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: hasImage
            ? Stack(
          children: [
            Positioned.fill(
              child: CommonNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                enableViewer: false,
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                height: 180,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.22),
                      Colors.black.withOpacity(0.78),
                    ],
                    stops: const [0.0, 0.45, 1.0],
                  ),
                ),
              ),
            ),
            Positioned(
              top: 16,
              left: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.38),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.12),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      CupertinoIcons.check_mark_circled_solid,
                      size: 14,
                      color: AppColors.white,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '오늘 인증 완료',
                      style: AppTextStyle.labelSmallStyle.copyWith(
                        color: AppColors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (item.imageUrls.length > 1)
              Positioned(
                top: 16,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.38),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.12),
                    ),
                  ),
                  child: Text(
                    '${item.imageUrls.length}장',
                    style: AppTextStyle.labelXSmallStyle.copyWith(
                      color: AppColors.white,
                    ),
                  ),
                ),
              ),
            Positioned(
              left: 18,
              right: 18,
              bottom: 18,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyle.headlineSmallMediumStyle.copyWith(
                      color: AppColors.white,
                      shadows: [
                        Shadow(
                          color: Colors.black.withOpacity(0.55),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _HeroInfoChip(
                        icon: CupertinoIcons.time_solid,
                        label: _formatCreatedAt(item.createdAt),
                      ),
                      _HeroInfoChip(
                        icon: CupertinoIcons.flame_fill,
                        label: typeText,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        )
            : _NoImageHeroBody(
          title: title,
          typeText: typeText,
          createdAt: item.createdAt,
          subType: item.subType,
        ),
      ),
    );
  }

  String _formatCreatedAt(DateTime dateTime) {
    final hour = dateTime.hour;
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? '오후' : '오전';
    final displayHour = hour % 12 == 0 ? 12 : hour % 12;
    return '$period $displayHour:$minute';
  }
}

class _HeroInfoChip extends StatelessWidget {
  const _HeroInfoChip({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.28),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: Colors.white.withOpacity(0.12),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppColors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppTextStyle.labelSmallStyle.copyWith(
              color: AppColors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _NoImageHeroBody extends StatelessWidget {
  const _NoImageHeroBody({
    required this.title,
    required this.typeText,
    required this.createdAt,
    required this.subType,
  });

  final String title;
  final String typeText;
  final DateTime createdAt;
  final String subType;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _HeroFallbackBackground(subType: subType),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.sky50,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: AppColors.borderSecondary),
                  ),
                  child: Text(
                    '오늘 인증 완료',
                    style: AppTextStyle.labelSmallStyle.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyle.headlineMediumBoldStyle.copyWith(
                    color: AppColors.textDefault,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  typeText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyle.bodyMediumStyle.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const Spacer(),
                Row(
                  children: [
                    const Icon(
                      CupertinoIcons.time_solid,
                      size: 15,
                      color: AppColors.icSecondary,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _formatCreatedAt(createdAt),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyle.labelMediumStyle.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(
                      CupertinoIcons.flame_fill,
                      size: 15,
                      color: AppColors.icSecondary,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        typeText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyle.labelMediumStyle.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _formatCreatedAt(DateTime dateTime) {
    final hour = dateTime.hour;
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? '오후' : '오전';
    final displayHour = hour % 12 == 0 ? 12 : hour % 12;
    return '$period $displayHour:$minute';
  }
}

class _HeroFallbackBackground extends StatelessWidget {
  const _HeroFallbackBackground({required this.subType});

  final String subType;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 220,
      width: double.infinity,
      color: AppColors.sky50,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SvgPicture.asset(
            'assets/svg/empty_image.svg',
            width: 64,
            height: 64,
          ),
          const SizedBox(height: 12),
          Text(
            '사진이 없는 오운완 기록이에요',
            style: AppTextStyle.bodyMediumStyle.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}