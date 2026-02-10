import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';
import '../../constants/app_text_style.dart';

class SectionHeader extends StatelessWidget {
  const SectionHeader({required this.title, required this.onTapAll});

  final String title;
  final VoidCallback onTapAll;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(title, style: AppTextStyle.titleMediumBoldStyle),
        const Spacer(),
        TextButton(
          onPressed: onTapAll,
          child: Text(
            '전체보기',
            style: AppTextStyle.labelMediumStyle.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}
