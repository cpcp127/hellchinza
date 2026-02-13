import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/app_text_style.dart';
import '../services/feed_service.dart';

class CommonPlaceWidget extends StatelessWidget {
  final String title;
  final String address;
  final double lat;
  final double lng;

  const CommonPlaceWidget({
    super.key,
    required this.title,
    required this.address,
    required this.lat,
    required this.lng,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        FeedService().openNaverMapPlace(
          title: title,
          lat: lat,
          lng: lng,
        );
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.bgSecondary,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderSecondary),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.place_outlined,
              size: 18,
              color: AppColors.icSecondary,
            ),
            const SizedBox(width: 8),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyle.titleSmallBoldStyle.copyWith(
                      color: AppColors.textDefault,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    address,
                    style: AppTextStyle.bodySmallStyle.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            const SizedBox(width: 6),
            const Icon(
              Icons.chevron_right,
              size: 18,
              color: AppColors.icSecondary,
            ),
          ],
        ),
      ),
    );
  }
}
