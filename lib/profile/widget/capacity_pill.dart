import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';
import '../../constants/app_text_style.dart';

class CapacityPill extends StatelessWidget {
  const CapacityPill({required this.current, required this.max});

  final int current;
  final int max;

  @override
  Widget build(BuildContext context) {
    final isFull = current >= max;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: isFull ? AppColors.red10 : AppColors.bgSecondary,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: isFull ? AppColors.borderError : AppColors.borderSecondary,
        ),
      ),
      child: Text(
        '$current/$max',
        style: AppTextStyle.labelXSmallStyle.copyWith(
          color: isFull ? AppColors.textError : AppColors.textSecondary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}