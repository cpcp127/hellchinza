import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/svg.dart';

import 'package:hellchinza/auth/providers/auth_provider.dart';
import 'package:hellchinza/constants/app_border_radius.dart';
import 'package:hellchinza/constants/app_colors.dart';
import 'package:hellchinza/constants/app_text_style.dart';
import 'package:hellchinza/constants/social_login_style.dart';
import 'package:hellchinza/services/policy_link_service.dart';

class AuthView extends ConsumerWidget {
  const AuthView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(authControllerProvider);
    final controller = ref.read(authControllerProvider.notifier);

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final horizontalPadding = 16.0;
            final contentWidth = constraints.maxWidth - (horizontalPadding * 2);
            final imageSize = contentWidth.clamp(160.0, 400.0);

            return SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 24),
                      const UnchinLoginHeader(),
                      const SizedBox(height: 20),
                      Center(
                        child: SizedBox(
                          width: imageSize,
                          height: imageSize,
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: AppBorderRadius.radius16,
                              image: const DecorationImage(
                                image: AssetImage('assets/icon/icon.png'),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Column(
                        children: [
                          SocialLoginButton(
                            type: SocialLoginType.apple,
                            enabled: !state.isLoading,
                            onTap: controller.signInWithApple,
                          ),
                          const SizedBox(height: 12),
                          SocialLoginButton(
                            type: SocialLoginType.google,
                            enabled: !state.isLoading,
                            onTap: controller.signInWithGoogle,
                          ),
                          const SizedBox(height: 12),
                          SocialLoginButton(
                            type: SocialLoginType.kakao,
                            enabled: !state.isLoading,
                            onTap: controller.signInWithKakao,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (state.errorMessage != null &&
                          state.errorMessage!.isNotEmpty) ...[
                        Center(
                          child: Text(
                            state.errorMessage!,
                            style: AppTextStyle.labelSmallStyle.copyWith(
                              color: AppColors.red100,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      Center(
                        child: _AuthAgreementSection(
                          onTapPrivacy: PolicyLinkService.openPrivacy,
                          onTapTerms: PolicyLinkService.openTerms,
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _AuthAgreementSection extends StatefulWidget {
  const _AuthAgreementSection({
    required this.onTapPrivacy,
    required this.onTapTerms,
  });

  final VoidCallback onTapPrivacy;
  final VoidCallback onTapTerms;

  @override
  State<_AuthAgreementSection> createState() => _AuthAgreementSectionState();
}

class _AuthAgreementSectionState extends State<_AuthAgreementSection> {
  late final TapGestureRecognizer _privacyRecognizer;
  late final TapGestureRecognizer _termsRecognizer;

  @override
  void initState() {
    super.initState();
    _privacyRecognizer = TapGestureRecognizer()..onTap = widget.onTapPrivacy;
    _termsRecognizer = TapGestureRecognizer()..onTap = widget.onTapTerms;
  }

  @override
  void didUpdateWidget(covariant _AuthAgreementSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    _privacyRecognizer.onTap = widget.onTapPrivacy;
    _termsRecognizer.onTap = widget.onTapTerms;
  }

  @override
  void dispose() {
    _privacyRecognizer.dispose();
    _termsRecognizer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final baseStyle = AppTextStyle.bodySmallStyle.copyWith(
      color: AppColors.textTeritary,
      height: 18 / 12,
    );

    final linkStyle = AppTextStyle.bodySmallStyle.copyWith(
      color: AppColors.textSecondary,
      decoration: TextDecoration.underline,
      decorationColor: AppColors.textSecondary,
      height: 18 / 12,
    );

    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        style: baseStyle,
        children: [
          const TextSpan(text: '계속 진행하면 가보자운동의\n'),
          TextSpan(
            text: '개인정보 처리방침',
            style: linkStyle,
            recognizer: _privacyRecognizer,
          ),
          const TextSpan(text: ' 및 '),
          TextSpan(
            text: '이용약관',
            style: linkStyle,
            recognizer: _termsRecognizer,
          ),
          const TextSpan(text: '에 동의한 것으로 간주됩니다.'),
        ],
      ),
    );
  }
}

class UnchinLoginHeader extends StatelessWidget {
  const UnchinLoginHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '가보자운동',
          style: AppTextStyle.headlineXLargeStyle.copyWith(
            color: AppColors.textDefault,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          '하루 한 번의 운동\n오늘도 기록해볼까요?',
          style: AppTextStyle.headlineSmallMediumStyle.copyWith(
            color: AppColors.textDefault,
          ),
        ),
      ],
    );
  }
}

class SocialLoginButton extends StatelessWidget {
  const SocialLoginButton({
    super.key,
    required this.type,
    required this.onTap,
    this.enabled = true,
  });

  final SocialLoginType type;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final style = SocialLoginStyle.of(type);

    return SizedBox(
      height: 56,
      width: double.infinity,
      child: Material(
        color: style.background,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(16),
          child: Opacity(
            opacity: enabled ? 1 : 0.55,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: style.borderColor != null
                    ? Border.all(color: style.borderColor!)
                    : null,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Row(
                children: [
                  SvgPicture.asset(
                    style.assetPath,
                    width: 22,
                    height: 22,
                    colorFilter: type == SocialLoginType.apple
                        ? ColorFilter.mode(style.iconColor, BlendMode.srcIn)
                        : null,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      _buttonText(type),
                      style: AppTextStyle.titleMediumBoldStyle.copyWith(
                        color: style.textColor,
                      ),
                    ),
                  ),
                  Icon(Icons.chevron_right, color: style.iconColor),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _buttonText(SocialLoginType type) {
    switch (type) {
      case SocialLoginType.apple:
        return 'Apple로 계속하기';
      case SocialLoginType.google:
        return 'Google로 계속하기';
      case SocialLoginType.naver:
        return '네이버로 계속하기';
      case SocialLoginType.kakao:
        return '카카오로 계속하기';
    }
  }
}
