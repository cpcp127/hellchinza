import 'package:flutter/material.dart';

import '../../../../../constants/app_colors.dart';
import '../../../../../constants/app_text_style.dart';

class OowStepShell extends StatelessWidget {
  const OowStepShell({
    super.key,
    required this.step,
    required this.title,
    required this.subTitle,
    required this.child,
  });

  final int step;
  final String title;
  final String subTitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      decoration: BoxDecoration(
        color: AppColors.bgWhite,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.borderSecondary),
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'STEP $step',
            style: AppTextStyle.labelSmallStyle.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: AppTextStyle.headlineSmallBoldStyle,
          ),
          const SizedBox(height: 6),
          Text(
            subTitle,
            style: AppTextStyle.bodyMediumStyle.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 24),
          Expanded(child: child),
        ],
      ),
    );
  }
}