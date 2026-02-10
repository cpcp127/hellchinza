import 'dart:ui';

import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/app_text_style.dart';

Future<bool> confirm(
    BuildContext context, {
      required String title,
      required String message,
      bool destructive = false,
      String confirmText = '확인',
      String cancelText = '취소',
    }) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) {
      return AlertDialog(
        backgroundColor: AppColors.bgWhite,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(
          title,
          style: AppTextStyle.titleMediumBoldStyle.copyWith(
            color: AppColors.textDefault,
          ),
        ),
        content: Text(
          message,
          style: AppTextStyle.bodyMediumStyle.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        actions: [
          Row(
            children: [
              Expanded(
                child: _ConfirmButton(
                  text: cancelText,
                  isPrimary: false,
                  onTap: () => Navigator.of(ctx).pop(false),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ConfirmButton(
                  text: confirmText,
                  isPrimary: true,
                  destructive: destructive,
                  onTap: () => Navigator.of(ctx).pop(true),
                ),
              ),
            ],
          ),
        ],
      );
    },
  );

  return result ?? false;
}
class _ConfirmButton extends StatelessWidget {
  const _ConfirmButton({
    required this.text,
    required this.onTap,
    required this.isPrimary,
    this.destructive = false,
  });

  final String text;
  final VoidCallback onTap;
  final bool isPrimary;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    Color border;

    if (isPrimary) {
      bg = destructive ? AppColors.red100 : AppColors.btnPrimary;
      fg = AppColors.white;
      border = Colors.transparent;
    } else {
      bg = AppColors.bgWhite;
      fg = AppColors.textSecondary;
      border = AppColors.borderSecondary;
    }

    return SizedBox(
      height: 44,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: border),
          ),
          child: Text(
            text,
            style: AppTextStyle.titleSmallBoldStyle.copyWith(color: fg),
          ),
        ),
      ),
    );
  }
}
