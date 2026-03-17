import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../constants/app_colors.dart';
import '../constants/app_text_style.dart';
import 'app_update_controller.dart';

class ForceUpdateView extends ConsumerWidget {
  const ForceUpdateView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appUpdateControllerProvider);

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.bgWhite,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                const Spacer(),
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    color: AppColors.sky50,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.system_update_alt_rounded,
                    size: 40,
                    color: AppColors.sky400,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  '업데이트가 필요해요',
                  style: AppTextStyle.headlineSmallBoldStyle.copyWith(
                    color: AppColors.textDefault,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  state.message ?? '더 안정적인 사용을 위해 최신 버전으로 업데이트해주세요.',
                  textAlign: TextAlign.center,
                  style: AppTextStyle.bodyMediumStyle.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '현재 ${state.currentVersion ?? '-'} / 최소 ${state.minRequiredVersion ?? '-'}',
                  style: AppTextStyle.labelSmallStyle.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () async {
                      final url = state.storeUrl;
                      if (url == null || url.isEmpty) return;
                      final uri = Uri.parse(url);
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.btnPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      '업데이트 하기',
                      style: AppTextStyle.titleMediumBoldStyle.copyWith(
                        color: AppColors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}