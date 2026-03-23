import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../constants/app_colors.dart';
import '../constants/app_text_style.dart';
import '../inquiry/presentation/inquiry_view.dart';
import '../notice/notice_list_view.dart';
import '../services/dialog_service.dart';
import '../services/snackbar_service.dart';
import '../setting/setting_controller.dart';
import '../withdraw/withdraw_view.dart';
import 'block_user_list.dart';

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
      appBar: AppBar(title: const Text('설정')),
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
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const WithdrawView()),
                    );
                  },
                ),
              ],
            ),

            const SizedBox(height: 16),

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
                _SettingTile(
                  title: '고객지원',
                  subtitle: '이용 중 도움이 필요하면 확인해 주세요',
                  isDestructive: false,
                  onTap: () async {
                    await _openUrl('https://hellchinza.web.app/support');
                  },
                ),
              ],
            ),

            const SizedBox(height: 16),

            _SettingSection(
              title: '정책 및 정보',
              children: [
                _SettingTile(
                  title: '개인정보 처리방침',
                  subtitle: '개인정보 수집 및 이용 내용을 확인합니다',
                  isDestructive: false,
                  onTap: () async {
                    await _openUrl('https://hellchinza.web.app/privacy');
                  },
                ),
                _SettingTile(
                  title: '이용약관',
                  subtitle: '서비스 이용약관을 확인합니다',
                  isDestructive: false,
                  onTap: () async {
                    await _openUrl('https://hellchinza.web.app/terms');
                  },
                ),
                _SettingTile(
                  title: '차단 사용자 관리',
                  subtitle: '차단한 사용자를 확인하고 해제할 수 있습니다',
                  isDestructive: false,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const BlockUserListView(),
                      ),
                    );
                  },
                ),
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

            const SizedBox(height: 16),

            _SettingSection(
              title: '알림 설정',
              children: [
                _SettingSwitchTile(
                  title: '채팅 알림',
                  subtitle: '새 채팅 메시지 알림을 받습니다',
                  value: state.notificationSettings['chat'] ?? true,
                  onChanged: (v) {
                    controller.updateNotificationSetting('chat', v);
                  },
                ),
                _SettingSwitchTile(
                  title: '댓글 알림',
                  subtitle: '내 피드에 댓글이 달리면 알림을 받습니다',
                  value: state.notificationSettings['comment'] ?? true,
                  onChanged: (v) {
                    controller.updateNotificationSetting('comment', v);
                  },
                ),
                _SettingSwitchTile(
                  title: '좋아요 알림',
                  subtitle: '내 피드에 좋아요가 눌리면 알림을 받습니다',
                  value: state.notificationSettings['like'] ?? true,
                  onChanged: (v) {
                    controller.updateNotificationSetting('like', v);
                  },
                ),
                _SettingSwitchTile(
                  title: '모임 알림',
                  subtitle: '모임 관련 알림을 받습니다',
                  value: state.notificationSettings['meet'] ?? true,
                  onChanged: (v) {
                    controller.updateNotificationSetting('meet', v);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);

    if (!ok) {
      SnackbarService.show(type: AppSnackType.error, message: '페이지를 열 수 없어요');
    }
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
            const Icon(Icons.chevron_right, color: AppColors.icSecondary),
          ],
        ),
      ),
    );
  }
}

class _SettingSwitchTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SettingSwitchTile({
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
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
                    color: AppColors.textDefault,
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
          CupertinoSwitch(
            value: value,
            activeColor: AppColors.btnPrimary,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
