import 'package:flutter/material.dart';
import 'package:hellchinza/common/common_network_image.dart';

import '../constants/app_colors.dart';
import '../constants/app_text_style.dart';
import '../feed/domain/feed_model.dart';

class ProfileFeedPreviewCard extends StatelessWidget {
  final FeedModel feed;
  final VoidCallback onTap;

  const ProfileFeedPreviewCard({
    super.key,
    required this.feed,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.bgWhite,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderSecondary),
        ),
        child: Row(
          children: [
            // 썸네일
            if (feed.imageUrls?.isNotEmpty ?? false)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CommonNetworkImage(
                  imageUrl: feed.imageUrls!.first,
                  width: 64,
                  height: 64,
                  fit: BoxFit.cover,
                ),
              )
            else
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.bgSecondary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.photo_outlined,
                  color: AppColors.icSecondary,
                ),
              ),

            const SizedBox(width: 12),

            // 텍스트 요약
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    feed.contents ?? '',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyle.bodyMediumStyle,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(
                        '좋아요 ${feed.likeUids?.length ?? 0}',
                        style: AppTextStyle.labelSmallStyle
                            .copyWith(color: AppColors.textSecondary),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '댓글 ${feed.commentCount ?? 0}',
                        style: AppTextStyle.labelSmallStyle
                            .copyWith(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
