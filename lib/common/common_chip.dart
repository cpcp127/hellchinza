import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/app_text_style.dart';

class CommonChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  const CommonChip({
    super.key,
    required this.label,
    required this.selected,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.translucent,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: selected
              ? AppColors.sky50        // ✅ 선택됨
              : AppColors.bgSecondary, // ✅ 기본
        ),
        child: Text(
          label,
          style: AppTextStyle.labelMediumStyle.copyWith(
            color: selected
                ? AppColors.textPrimary
                : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}




class CommonChipWrap extends StatelessWidget {
  final List<String> items;
  final List<String> selectedItems;
  final void Function(String value) onTap;

  const CommonChipWrap({
    super.key,
    required this.items,
    required this.selectedItems,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: items.map((item) {
        final selected = selectedItems.contains(item);
        return CommonChip(
          label: item,
          selected: selected,
          onTap: () => onTap(item),
        );
      }).toList(),
    );
  }
}
