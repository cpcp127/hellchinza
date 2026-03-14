import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';
import '../../constants/app_text_style.dart';

class EmptyList extends StatelessWidget {
  const EmptyList({
    required this.onTapCreate,
    required this.title,
    required this.subTitle, required this.btnTitle,
  });

  final String title;
  final String subTitle;
  final String btnTitle;
  final VoidCallback onTapCreate;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 60, 16, 16),
      children: [
        Text(
          title,
          style: AppTextStyle.headlineSmallBoldStyle.copyWith(
            color: AppColors.textDefault,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 10),
        Text(
          subTitle,
          style: AppTextStyle.bodyMediumStyle.copyWith(
            color: AppColors.textSecondary,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 18),
        SizedBox(
          height: 52,
          child: ElevatedButton(
            onPressed: onTapCreate,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.btnPrimary,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Text(
              btnTitle,
              style: AppTextStyle.titleMediumBoldStyle.copyWith(
                color: AppColors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
