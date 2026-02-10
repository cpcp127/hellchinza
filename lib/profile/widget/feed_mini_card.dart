import 'package:flutter/material.dart';
import 'package:hellchinza/utils/date_time_util.dart';

import '../../common/common_network_image.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_text_style.dart';
import '../../feed/domain/feed_model.dart';
import '../../feed/feed_detail/feed_detail_view.dart';
import 'feed_type_pill.dart';

class FeedMiniCard extends StatelessWidget {
  const FeedMiniCard({required this.feed});

  final FeedModel feed;

  @override
  Widget build(BuildContext context) {
    final hasImage = feed.imageUrls?.isNotEmpty == true;
    final thumb = hasImage ? feed.imageUrls!.first : null;

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => FeedDetailView(feedId: feed.id)),
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.bgWhite,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.borderSecondary),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Container(
                width: 56,
                height: 56,
                color: AppColors.bgSecondary,
                child: thumb == null
                    ? Icon(
                  mainTypeIcon(feed.mainType),
                  color: AppColors.icDisabled,
                )
                    : CommonNetworkImage(
                  imageUrl: thumb,
                  height: 56,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      FeedTypePill(mainType: feed.mainType),
                      if (feed.subType != null) ...[
                        const SizedBox(width: 6),
                        Text(
                          feed.subType!,
                          style: AppTextStyle.labelSmallStyle.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    (feed.contents ?? '').trim().isEmpty
                        ? fallbackTitle(feed.mainType)
                        : feed.contents!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyle.bodyMediumStyle.copyWith(
                      color: AppColors.textDefault,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    DateTimeUtil.formatMonthTimeDateTime(feed.createdAt),
                    style: AppTextStyle.labelXSmallStyle.copyWith(
                      color: AppColors.textTeritary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right, color: AppColors.icSecondary),
          ],
        ),
      ),
    );
  }

  static IconData mainTypeIcon(String t) {
    switch (t) {
      case '오운완':
        return Icons.fitness_center_outlined;
      case '식단':
        return Icons.restaurant_outlined;
      case '질문':
        return Icons.help_outline;
      case '후기':
        return Icons.rate_review_outlined;
      default:
        return Icons.feed_outlined;
    }
  }

  static String fallbackTitle(String t) {
    switch (t) {
      case '오운완':
        return '오늘 운동 기록';
      case '식단':
        return '오늘 식단 기록';
      case '질문':
        return '질문이 있어요';
      case '후기':
        return '운동 후기';
      default:
        return '피드';
    }
  }
}