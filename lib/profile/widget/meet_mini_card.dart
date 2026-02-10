import 'package:flutter/material.dart';

import '../../common/common_network_image.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_text_style.dart';
import '../../meet/meet_detail/meat_detail_view.dart';
import '../../meet/domain/meet_model.dart';
import '../../utils/date_time_util.dart';
import 'capacity_pill.dart';

class MeetMiniCard extends StatelessWidget {
  const MeetMiniCard({required this.meet});

  final MeetModel meet;

  @override
  Widget build(BuildContext context) {
    final hasImage = meet.imageUrls.isNotEmpty;

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => MeetDetailView(meetId: meet.id)),
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
                child: hasImage
                    ? CommonNetworkImage(
                  imageUrl: meet.imageUrls.first,
                  height: 56,
                  fit: BoxFit.cover,
                )
                    : const Icon(
                  Icons.image_outlined,
                  color: AppColors.icDisabled,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    meet.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyle.titleSmallBoldStyle,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${meet.category}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyle.bodySmallStyle.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    meet.regions.first.fullName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyle.bodySmallStyle.copyWith(
                      color: AppColors.textTeritary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            CapacityPill(
              current: meet.currentMemberCount,
              max: meet.maxMembers,
            ),
          ],
        ),
      ),
    );
  }
}