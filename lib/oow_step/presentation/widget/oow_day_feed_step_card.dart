import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:hellchinza/common/common_network_image.dart';
import 'package:hellchinza/feed/feed_detail/feed_detail_view.dart';

import '../../../../../constants/app_colors.dart';
import '../../../../../constants/app_text_style.dart';

import '../oow_step_controller.dart';
import '../oow_step_state.dart';
import 'oow_step_shell.dart';

class OowDayFeedStepPage extends ConsumerWidget {
  const OowDayFeedStepPage({super.key, required this.uid});

  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(oowStepControllerProvider(uid));
    final controller = ref.read(oowStepControllerProvider(uid).notifier);

    final weekDays = List.generate(
      7,
      (index) => state.weekStart.add(Duration(days: index)),
    );

    return OowStepShell(
      step: 2,
      title: '날짜별 피드',
      subTitle: '날짜를 눌러 그날 작성한 오운완 피드를 확인해보세요',
      child: Column(
        children: [
          SizedBox(
            height: 100,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: weekDays.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final day = weekDays[index];
                final isSelected = _isSameDate(day, state.selectedDay);
                final count = state.weekMap[_dateKey(day)]?.length ?? 0;

                return GestureDetector(
                  onTap: () => controller.selectDay(day),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOut,
                    width: 58,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.btnPrimary
                          : AppColors.bgSecondary,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.borderPrimary
                            : AppColors.borderSecondary,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _weekdayText(day.weekday),
                          style: AppTextStyle.labelSmallStyle.copyWith(
                            color: isSelected
                                ? AppColors.white
                                : AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${day.day}',
                          style: AppTextStyle.titleSmallBoldStyle.copyWith(
                            color: isSelected
                                ? AppColors.white
                                : AppColors.textDefault,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$count',
                          style: AppTextStyle.labelXSmallStyle.copyWith(
                            color: isSelected
                                ? AppColors.white.withValues(alpha: 0.9)
                                : AppColors.textTeritary,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 280),
              child: state.selectedDayFeeds.isEmpty
                  ? const _EmptyDayFeeds(key: ValueKey('empty'))
                  : ListView.separated(
                      key: ValueKey(_dateKey(state.selectedDay)),
                      scrollDirection: Axis.horizontal,
                      itemCount: state.selectedDayFeeds.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (context, index) {
                        final item = state.selectedDayFeeds[index];

                        return TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: 1),
                          duration: Duration(milliseconds: 220 + (index * 90)),
                          curve: Curves.easeOutCubic,
                          builder: (context, value, child) {
                            return Opacity(
                              opacity: value,
                              child: Transform.translate(
                                offset: Offset(18 * (1 - value), 0),
                                child: child,
                              ),
                            );
                          },
                          child: OowFeedSwipeCard(
                            item: item,
                            onTap: () {
                              Navigator.push(
                                context,
                                CupertinoPageRoute(
                                  fullscreenDialog: true,
                                  builder: (context) {
                                    return FeedDetailView(feedId: item.id);
                                  },
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  bool _isSameDate(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _weekdayText(int weekday) {
    const map = ['월', '화', '수', '목', '금', '토', '일'];
    return map[weekday - 1];
  }

  String _dateKey(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    return '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }
}

class _EmptyDayFeeds extends StatelessWidget {
  const _EmptyDayFeeds({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        '선택한 날짜의 오운완 피드가 없어요',
        style: AppTextStyle.bodyMediumStyle.copyWith(
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

class _FeedPreviewCard extends StatelessWidget {
  const _FeedPreviewCard({required this.item, required this.onTap});

  final OowFeedItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasImage = item.imageUrls.isNotEmpty;
    final imageUrl = hasImage ? item.imageUrls.first : null;

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.bgWhite,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.borderSecondary),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _FeedPreviewTextSection(item: item)),
            if (hasImage) ...[
              const SizedBox(width: 12),
              _FeedPreviewThumbnail(imageUrl: imageUrl!),
            ],
          ],
        ),
      ),
    );
  }
}

class _FeedPreviewTextSection extends StatelessWidget {
  const _FeedPreviewTextSection({required this.item});

  final OowFeedItem item;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 100,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (item.subType.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.sky50,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                item.subType,
                style: AppTextStyle.labelXSmallStyle.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          if (item.subType.isNotEmpty) const SizedBox(height: 8),
          Text(
            item.text.isEmpty ? '오운완 기록' : item.text,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyle.bodyMediumStyle.copyWith(
              color: AppColors.textDefault,
            ),
          ),
          const Spacer(),
          Row(
            children: [
              Icon(
                Icons.schedule_rounded,
                size: 14,
                color: AppColors.icSecondary,
              ),
              const SizedBox(width: 4),
              Text(
                _timeText(item.createdAt),
                style: AppTextStyle.labelXSmallStyle.copyWith(
                  color: AppColors.textTeritary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _timeText(DateTime date) {
    final h = date.hour.toString().padLeft(2, '0');
    final m = date.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

class _FeedPreviewThumbnail extends StatelessWidget {
  const _FeedPreviewThumbnail({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 88,
        height: 88,
        color: AppColors.bgSecondary,
        child: Image.network(
          imageUrl,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              color: AppColors.bgSecondary,
              alignment: Alignment.center,
              child: Icon(
                Icons.image_not_supported_outlined,
                size: 20,
                color: AppColors.icDisabled,
              ),
            );
          },
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return Container(
              color: AppColors.bgSecondary,
              alignment: Alignment.center,
              child: const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            );
          },
        ),
      ),
    );
  }
}

class OowFeedSwipeCard extends StatelessWidget {
  const OowFeedSwipeCard({
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
    final title =
    item.text.trim().isEmpty ? '오운완 기록' : item.text.trim();
    final typeText =
    item.subType.trim().isEmpty ? '운동 기록' : item.subType.trim();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 260,
        decoration: BoxDecoration(
          color: AppColors.bgWhite,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.borderSecondary),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: hasImage
            ? Stack(
          children: [
            Positioned.fill(
              child: Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) {
                  return _FeedFallbackBackground(subType: item.subType);
                },
              ),
            ),

            // 하단 오버레이
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                height: 118,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.45),
                      Colors.black.withOpacity(0.78),
                    ],
                    stops: const [0.0, 0.55, 1.0],
                  ),
                ),
              ),
            ),

            // 상단 사진 수 pill
            if (item.imageUrls.length > 1)
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.45),
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
              left: 14,
              right: 14,
              bottom: 14,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyle.titleSmallBoldStyle.copyWith(
                      color: AppColors.white,
                      shadows: [
                        Shadow(
                          color: Colors.black.withOpacity(0.6),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(
                        CupertinoIcons.time_solid,
                        size: 14,
                        color: AppColors.white,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          _formatCreatedAt(item.createdAt),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                          AppTextStyle.labelSmallStyle.copyWith(
                            color: AppColors.white,
                            shadows: [
                              Shadow(
                                color: Colors.black.withOpacity(0.55),
                                blurRadius: 6,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(
                        CupertinoIcons.flame_fill,
                        size: 14,
                        color: AppColors.white,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          typeText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                          AppTextStyle.labelSmallStyle.copyWith(
                            color: AppColors.white,
                            shadows: [
                              Shadow(
                                color: Colors.black.withOpacity(0.55),
                                blurRadius: 6,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        )
            : _NoImageCardBody(
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

class _NoImageCardBody extends StatelessWidget {
  const _NoImageCardBody({
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
    return Container(
      // color: AppColors.bgWhite,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _FeedFallbackBackground(subType: subType),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyle.titleSmallBoldStyle.copyWith(
                      color: AppColors.textDefault,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    typeText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyle.bodySmallStyle.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      const Icon(
                        CupertinoIcons.time_solid,
                        size: 14,
                        color: AppColors.icSecondary,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          _formatCreatedAt(createdAt),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyle.labelSmallStyle.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(
                        CupertinoIcons.flame_fill,
                        size: 14,
                        color: AppColors.icSecondary,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          typeText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyle.labelSmallStyle.copyWith(
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

class _FeedFallbackBackground extends StatelessWidget {
  const _FeedFallbackBackground({
    required this.subType,
  });

  final String subType;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.only(topLeft: Radius.circular(24),topRight: Radius.circular(24)),
      child: Container(
        height: 132,
        width: double.infinity,
        color: AppColors.sky50,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SvgPicture.asset('assets/svg/empty_image.svg'),
            SizedBox(height: 8),
            Text('사진이 없어요',style: AppTextStyle.labelSmallStyle,)
          ],
        ),
      ),
    );
  }

}