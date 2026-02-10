import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/app_text_style.dart';

class CommonActionSheetItem {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final bool isDestructive;

  const CommonActionSheetItem({
    required this.icon,
    required this.title,
    required this.onTap,
    this.isDestructive = false,
  });
}

class CommonActionSheet extends StatelessWidget {
  final String? title;
  final List<CommonActionSheetItem> items;

  const CommonActionSheet({
    super.key,
    this.title,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
        decoration: const BoxDecoration(
          color: AppColors.bgWhite,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 핸들
            Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.gray200,
                borderRadius: BorderRadius.circular(99),
              ),
            ),

            if (title != null) ...[
              const SizedBox(height: 14),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  title!,
                  style: AppTextStyle.titleMediumBoldStyle.copyWith(
                    color: AppColors.textDefault,
                  ),
                ),
              ),
            ],

            const SizedBox(height: 12),

            // 액션 리스트
            ...items.map((e) => _ActionRow(item: e)),

            const SizedBox(height: 6),

            // 취소
            _CancelButton(onTap: () => Navigator.pop(context)),
          ],
        ),
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  final CommonActionSheetItem item;
  const _ActionRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final Color iconColor =
    item.isDestructive ? AppColors.icError : AppColors.icDefault;
    final Color textColor =
    item.isDestructive ? AppColors.textError : AppColors.textDefault;

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () {
        Navigator.pop(context); // 먼저 닫고
        item.onTap();           // 액션 실행
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.bgSecondary,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.borderTertiary),
        ),
        child: Row(
          children: [
            Icon(item.icon, size: 20, color: iconColor),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                item.title,
                style: AppTextStyle.titleMediumStyle.copyWith(
                  color: textColor,
                ),
              ),
            ),
            Icon(Icons.chevron_right, size: 20, color: AppColors.icDisabled),
          ],
        ),
      ),
    );
  }
}

class _CancelButton extends StatelessWidget {
  final VoidCallback onTap;
  const _CancelButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.bgWhite,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.borderSecondary),
        ),
        child: Center(
          child: Text(
            '취소',
            style: AppTextStyle.titleMediumBoldStyle.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
