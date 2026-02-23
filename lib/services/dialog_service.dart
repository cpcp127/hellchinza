import 'package:flutter/material.dart';

import '../common/common_text_field.dart';
import '../constants/app_colors.dart';
import '../constants/app_text_style.dart';

class DialogService {
  DialogService._();

  /// 🔥 기본 확인 다이얼로그 (취소 / 확인)
  static Future<bool?> showConfirm({
    required BuildContext context,
    required String title,
    required String message,
    String cancelText = '취소',
    String confirmText = '확인',
    bool barrierDismissible = true,
    bool isDestructive = false, // 확인버튼 빨간색 여부
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (_) {
        return AlertDialog(
          backgroundColor: AppColors.bgWhite,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
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
              height: 1.35,
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: [
            Row(
              children: [
                Expanded(
                  child: _OutlineButton(
                    text: cancelText,
                    onTap: () => Navigator.pop(context, false),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _PrimaryButton(
                    text: confirmText,
                    onTap: () => Navigator.pop(context, true),
                    isDestructive: isDestructive,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  static Future<String?> showTextInput({
    required BuildContext context,
    required String title,
    required String hintText,
    String cancelText = '취소',
    String confirmText = '확인',
    String? initialText,
    bool barrierDismissible = true,
  }) {
    final controller = TextEditingController(text: initialText ?? '');

    return showDialog<String>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (_) {
        return AlertDialog(
          backgroundColor: AppColors.bgWhite,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            title,
            style: AppTextStyle.titleMediumBoldStyle.copyWith(
              color: AppColors.textDefault,
            ),
          ),
          content: CommonTextField(
            controller: controller,
            hintText: hintText,
            maxLines: 1,
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: [
            Row(
              children: [
                Expanded(
                  child: _OutlineButton(
                    text: cancelText,
                    onTap: () => Navigator.pop(context, null),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _PrimaryButton(
                    text: confirmText,
                    onTap: () {

                      final text = controller.text.trim();
                      if(text.isEmpty) return;
                      Navigator.pop(
                        context,
                        text.isEmpty ? '같이 운동해요! 🙂' : text,
                      );
                    },
                    isDestructive: false,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  /// 🔥 기본 확인 다이얼로그 (취소 / 확인)
  static Future<bool?> showConfirmOneButton({
    required BuildContext context,
    required String title,
    required String message,

    String confirmText = '확인',
    bool barrierDismissible = true,
    bool isDestructive = false, // 확인버튼 빨간색 여부
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (_) {
        return AlertDialog(
          backgroundColor: AppColors.bgWhite,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
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
              height: 1.35,
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: [
            Row(
              children: [
               
                Expanded(
                  child: _PrimaryButton(
                    text: confirmText,
                    onTap: () => Navigator.pop(context, true),
                    isDestructive: isDestructive,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

/// ------------------ 내부 버튼 위젯 ------------------

class _OutlineButton extends StatelessWidget {
  const _OutlineButton({
    required this.text,
    required this.onTap,
  });

  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: AppColors.borderSecondary),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          backgroundColor: AppColors.bgWhite,
        ),
        child: Text(
          text,
          style: AppTextStyle.labelMediumStyle.copyWith(
            color: AppColors.textDefault,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.text,
    required this.onTap,
    required this.isDestructive,
  });

  final String text;
  final VoidCallback onTap;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor:
          isDestructive ? AppColors.textError : AppColors.btnPrimary,
          disabledBackgroundColor: AppColors.btnDisabled,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        child: Text(
          text,
          style: AppTextStyle.labelMediumStyle.copyWith(
            color: AppColors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}