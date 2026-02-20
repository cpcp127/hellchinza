import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hellchinza/setting/setting_controller.dart';

import '../auth/presentation/auth_controller.dart';
import '../constants/app_colors.dart';
import '../constants/app_text_style.dart';
import '../services/dialog_service.dart';
import '../services/snackbar_service.dart';

class SettingView extends ConsumerWidget {
  const SettingView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(settingControllerProvider);
    final controller = ref.read(settingControllerProvider.notifier);
    return Scaffold(
      appBar: AppBar(title: Text('설정')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            _SettingSection(
              title: '계정',
              children: [
                _SettingTile(
                  title: '로그아웃',
                  subtitle: '현재 계정에서 로그아웃합니다',
                  isDestructive: false,
                  onTap: () async {
                    final ok = await _confirm(
                      context,
                      title: '로그아웃할까요?',
                      message: '로그아웃하면 다시 로그인해야 합니다.',
                      destructive: false,
                    );
                    if (!ok) return;
                    try {
                      await controller.logout(context);
                      SnackbarService.show(
                        type: AppSnackType.success,
                        message: '로그아웃 되었습니다',
                      );
                      // 필요하면 로그인 화면으로 이동
                    } catch (_) {
                      SnackbarService.show(
                        type: AppSnackType.error,
                        message:
                            ref.read(settingControllerProvider).errorMessage ??
                            '로그아웃 실패',
                      );
                    }
                  },
                ),
                _SettingTile(
                  title: '회원탈퇴',
                  subtitle: '계정과 관련 데이터를 삭제합니다',
                  isDestructive: true,
                  onTap: () async {
                    final ok = await _confirm(
                      context,
                      title: '회원탈퇴할까요?',
                      message: '탈퇴 후에는 되돌릴 수 없습니다.',
                      destructive: true,
                    );
                    if (!ok) return;
                    try {
                      await controller.deleteAccount();
                      SnackbarService.show(
                        type: AppSnackType.success,
                        message: '회원탈퇴가 완료되었습니다',
                      );
                      // 필요하면 로그인 화면으로 이동
                    } catch (_) {
                      SnackbarService.show(
                        type: AppSnackType.error,
                        message: '회원탈퇴 실패',
                      );
                    }
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<bool> _confirm(
    BuildContext context, {
    required String title,
    required String message,
    required bool destructive,
  }) async {
    final result = await DialogService.showConfirm(
      context: context,
      title: title,
      message: message,
      confirmText: '확인',
      isDestructive: destructive,
    );

    return result ?? false;
  }
}

class _SettingSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SettingSection({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bgWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderSecondary),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTextStyle.titleSmallBoldStyle.copyWith(
              color: AppColors.textDefault,
            ),
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }
}

class _SettingTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool isDestructive;
  final VoidCallback onTap;

  const _SettingTile({
    required this.title,
    this.subtitle,
    required this.isDestructive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final titleColor = isDestructive
        ? AppColors.textError
        : AppColors.textDefault;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.translucent,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyle.titleSmallBoldStyle.copyWith(
                      color: titleColor,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle!,
                      style: AppTextStyle.bodySmallStyle.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: AppColors.icSecondary),
          ],
        ),
      ),
    );
  }
}
