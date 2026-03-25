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
      backgroundColor: AppColors.bgWhite,
      body: Column(
        children: [
          Container(
            width: double.infinity,
            height: MediaQuery.of(context).size.height / 1.8,
            decoration: BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/icon/icon.png'),
                fit: BoxFit.cover,
              ),
            ),
          ),
          Expanded(
            child: Transform.translate(
              offset: const Offset(0, -28),
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(height: 20),
                      Text(
                        '가보자운동',
                        style: AppTextStyle.headlineLargeStyle.copyWith(
                          color: AppColors.textDefault,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '간편 로그인으로 바로 시작해보세요',
                        style: AppTextStyle.bodyMediumStyle.copyWith(
                          color: AppColors.textSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 20),
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
                      Expanded(child: SizedBox()),
                      _AuthAgreementSection(
                        onTapPrivacy: PolicyLinkService.openPrivacy,
                        onTapTerms: PolicyLinkService.openTerms,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      // body: SafeArea(
      //   child: LayoutBuilder(
      //     builder: (context, constraints) {
      //       final compact = constraints.maxHeight < 760;
      //       final topHeight = compact ? 360.0 : 420.0;
      //
      //       return SingleChildScrollView(
      //         physics: const ClampingScrollPhysics(),
      //         child: ConstrainedBox(
      //           constraints: BoxConstraints(
      //             minHeight: constraints.maxHeight,
      //           ),
      //           child: Column(
      //             children: [
      //               SizedBox(
      //                 height: topHeight,
      //                 width: double.infinity,
      //                 child: Container(
      //                   width: double.infinity,
      //                  // padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      //                   decoration: const BoxDecoration(
      //                     color: AppColors.sky400,
      //                     image: DecorationImage(
      //                       image: AssetImage('assets/icon/icon.png'),
      //                       fit: BoxFit.cover,
      //                     ),
      //                   ),
      //                   child: Stack(
      //                     children: [
      //                       Positioned.fill(
      //                         child: Container(
      //                           decoration: BoxDecoration(
      //                             gradient: LinearGradient(
      //                               begin: Alignment.topCenter,
      //                               end: Alignment.bottomCenter,
      //                               colors: [
      //                                 Colors.black.withOpacity(0.1),
      //                                 Colors.black.withOpacity(0.4),
      //                               ],
      //                             ),
      //                           ),
      //                         ),
      //                       ),
      //                       Padding(
      //                         padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      //                         child: Column(
      //                           crossAxisAlignment: CrossAxisAlignment.start,
      //                           children: [
      //                             const Spacer(),
      //                             Text(
      //                               '오늘의 운동을 기록하고\n꾸준한 루틴을 만들어보세요',
      //                               style: AppTextStyle.headlineLargeStyle.copyWith(
      //                                 color: AppColors.white,
      //                               ),
      //                             ),
      //                             const SizedBox(height: 10),
      //                             Text(
      //                               '가보자운동에서 운동 인증과 기록을\n쉽고 자연스럽게 이어가보세요',
      //                               style: AppTextStyle.bodyMediumStyle.copyWith(
      //                                 color: AppColors.white.withOpacity(0.88),
      //                               ),
      //                             ),
      //                             SizedBox(height: compact ? 28 : 40),
      //                             SizedBox(height: 10,)
      //                           ],
      //                         ),
      //                       ),
      //                     ],
      //                   ),
      //                 ),
      //               ),
      //               Transform.translate(
      //                 offset: const Offset(0, -28),
      //                 child: Container(
      //                   width: double.infinity,
      //                   padding: EdgeInsets.fromLTRB(
      //                     20,
      //                     compact ? 24 : 28,
      //                     20,
      //                     compact ? 20 : 24,
      //                   ),
      //                   decoration: BoxDecoration(
      //                     color: AppColors.bgWhite,
      //                     borderRadius: const BorderRadius.only(
      //                       topLeft: Radius.circular(32),
      //                       topRight: Radius.circular(32),
      //                     ),
      //                     boxShadow: [
      //                       BoxShadow(
      //                         color: Colors.black.withOpacity(0.06),
      //                         blurRadius: 20,
      //                         offset: const Offset(0, -6),
      //                       ),
      //                     ],
      //                   ),
      //                   child: Column(
      //                     mainAxisSize: MainAxisSize.min,
      //                     children: [
      //                       Text(
      //                         '가보자운동',
      //                         style:
      //                         AppTextStyle.headlineSmallBoldStyle.copyWith(
      //                           color: AppColors.textDefault,
      //                         ),
      //                       ),
      //                       const SizedBox(height: 8),
      //                       Text(
      //                         '간편 로그인으로 바로 시작해보세요',
      //                         style: AppTextStyle.bodyMediumStyle.copyWith(
      //                           color: AppColors.textSecondary,
      //                         ),
      //                         textAlign: TextAlign.center,
      //                       ),
      //                       SizedBox(height: compact ? 20 : 28),
      //                       SocialLoginButton(
      //                         type: SocialLoginType.apple,
      //                         enabled: !state.isLoading,
      //                         onTap: controller.signInWithApple,
      //                       ),
      //                       const SizedBox(height: 12),
      //                       SocialLoginButton(
      //                         type: SocialLoginType.google,
      //                         enabled: !state.isLoading,
      //                         onTap: controller.signInWithGoogle,
      //                       ),
      //                       const SizedBox(height: 12),
      //                       SocialLoginButton(
      //                         type: SocialLoginType.kakao,
      //                         enabled: !state.isLoading,
      //                         onTap: controller.signInWithKakao,
      //                       ),
      //                       SizedBox(height: compact ? 20 : 24),
      //                       _AuthAgreementSection(
      //                         onTapPrivacy: PolicyLinkService.openPrivacy,
      //                         onTapTerms: PolicyLinkService.openTerms,
      //                       ),
      //                     ],
      //                   ),
      //                 ),
      //               ),
      //             ],
      //           ),
      //         ),
      //       );
      //     },
      //   ),
      // ),
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
