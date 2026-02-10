import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';
import '../../constants/app_text_style.dart';

class EmptyMeetList extends StatelessWidget {
  const EmptyMeetList({required this.onTapCreate});

  final VoidCallback onTapCreate;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 60, 16, 16),
      children: [
        Text(
          '아직 모임이 없어요',
          style: AppTextStyle.headlineSmallBoldStyle.copyWith(
            color: AppColors.textDefault,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 10),
        Text(
          '운동친구를 모으는 첫 모임을 만들어볼까요?',
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
              '모임 만들기',
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