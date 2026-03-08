import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hellchinza/setting/setting_controller.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../auth/presentation/auth_controller.dart';
import '../constants/app_colors.dart';
import '../constants/app_text_style.dart';
import '../inquiry/inquiry_view.dart';
import '../notice/notice_list_view.dart';
import '../services/dialog_service.dart';
import '../services/snackbar_service.dart';

class SettingView extends ConsumerStatefulWidget {
  const SettingView({super.key});

  @override
  ConsumerState<SettingView> createState() => _SettingViewState();
}

class _SettingViewState extends ConsumerState<SettingView> {

  @override
  Widget build(BuildContext context) {
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

            const SizedBox(height: 16),

            // ---------------- 고객센터 ----------------
            _SettingSection(
              title: '고객센터',
              children: [
                _SettingTile(
                  title: '공지사항',
                  subtitle: '서비스 업데이트 및 공지 확인',
                  isDestructive: false,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const NoticeListView()),
                    );
                  },
                ),
                _SettingTile(
                  title: '문의하기',
                  subtitle: '서비스 관련 문의를 남겨주세요',
                  isDestructive: false,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const InquiryView()),
                    );
                  },
                ),
              ],
            ),

            const SizedBox(height: 16),

            // ---------------- 앱 정보 ----------------
            _SettingSection(
              title: '앱 정보',
              children: [
                _SettingTile(
                  title: '버전 정보',
                  subtitle: '현재 앱 버전 확인',
                  isDestructive: false,
                  onTap: () async {
                    final packageInfo = await PackageInfo.fromPlatform();

                    await DialogService.showConfirmOneButton(
                      context: context,
                      title: '버전 정보',
                      message: '현재 버전: ${packageInfo.version}',
                      confirmText: '확인',
                    );
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(settingControllerProvider.notifier).init();
    });
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
