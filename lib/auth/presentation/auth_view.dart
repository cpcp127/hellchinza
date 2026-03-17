import 'dart:async';
import 'package:flutter/gestures.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/svg.dart';
import 'package:hellchinza/auth/presentation/auth_controller.dart';
import 'package:hellchinza/constants/app_border_radius.dart';
import 'package:hellchinza/services/policy_link_service.dart';

import '../../constants/app_colors.dart';
import '../../constants/app_text_style.dart';
import '../../constants/social_login_style.dart';

class AuthView extends ConsumerStatefulWidget {
  const AuthView({super.key});

  @override
  ConsumerState createState() => _AuthViewState();
}

class _AuthViewState extends ConsumerState<AuthView> {
  late final PageController pageController;
  int pageIndex = 0;
  Timer? timer;
  List<String> imagePath = [
    'assets/images/auth_health.png',
    'assets/images/auth_climing.png',
    'assets/images/auth_running.png',
    'assets/images/auth_badminton.png',
    'assets/images/auth_bowling.png',
  ];

  @override
  Widget build(BuildContext context) {
    final controller = ref.refresh(authControllerProvider.notifier);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 36),

              const UnchinLoginHeader(),
              const SizedBox(height: 20),
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: 400,
                    maxHeight: 400,
                  ),
                  child: AspectRatio(
                    aspectRatio: 1, // 👈 1:1 비율
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
              ),
              Spacer(),
              Column(
                children: [
                  SocialLoginButton(
                    type: SocialLoginType.apple,
                    onTap: () {
                      ref
                          .read(authControllerProvider.notifier)
                          .signInWithApple();
                    },
                  ),
                  const SizedBox(height: 12),
                  SocialLoginButton(
                    type: SocialLoginType.google,
                    onTap: () {
                      ref
                          .read(authControllerProvider.notifier)
                          .signInWithGoogle();
                    },
                  ),
                  const SizedBox(height: 12),
                  SocialLoginButton(
                    type: SocialLoginType.kakao,
                    onTap: () {
                      ref
                          .read(authControllerProvider.notifier)
                          .signInWithKakao();
                    },
                  ),
                ],
              ),

              const SizedBox(height: 16),

              Center(
                child: _AuthAgreementSection(
                  onTapPrivacy: () {
                    PolicyLinkService.openPrivacy();
                  },
                  onTapTerms: () {
                    PolicyLinkService.openTerms();
                  },
                ),
              ),

              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildSocialButton({
    required String title,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 150,
        height: 40,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(99),
          color: Colors.blue,
        ),
        child: Center(child: Text(title)),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    pageController = PageController();

    timer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!pageController.hasClients) return;

      pageIndex = (pageIndex + 1) % imagePath.length;
      pageController.animateToPage(
        pageIndex,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    pageController.dispose();
    super.dispose();
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

        // 보조 문장(2줄까지 자연스럽게)
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
  const SocialLoginButton({super.key, required this.type, required this.onTap});

  final SocialLoginType type;
  final VoidCallback onTap;

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
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
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
                /// SVG 아이콘
                SvgPicture.asset(
                  style.assetPath,
                  width: 22,
                  height: 22,
                  colorFilter: type == SocialLoginType.apple
                      ? ColorFilter.mode(style.iconColor, BlendMode.srcIn)
                      : null,
                ),

                const SizedBox(width: 14),

                /// 텍스트
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
