import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';
import '../../constants/app_text_style.dart';
import 'feed_mini_card.dart';

class FeedTypePill extends StatelessWidget {
  const FeedTypePill({required this.mainType});

  final String mainType;

  @override
  Widget build(BuildContext context) {
    final icon = FeedMiniCard.mainTypeIcon(mainType);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.sky50,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.borderPrimary),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.icPrimary),
          const SizedBox(width: 6),
          Text(
            mainType,
            style: AppTextStyle.labelXSmallStyle.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
