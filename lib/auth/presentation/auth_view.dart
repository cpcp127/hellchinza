import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/svg.dart';
import 'package:hellchinza/auth/presentation/auth_controller.dart';
import 'package:hellchinza/constants/app_border_radius.dart';

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
    'assets/images/auth_bowling.png'
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 36),

            // ===== Brand =====
            Align(alignment: Alignment.centerLeft, child: UnchinLoginHeader()),
            const SizedBox(height: 12),
            Expanded(child: PageView.builder(
              controller: pageController,
              itemCount: imagePath.length,
              physics: const NeverScrollableScrollPhysics(), // 👈 자동만
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image.asset(
                      imagePath[index],
                      fit: BoxFit.cover, // 👈 일러스트 느낌 유지
                    ),
                  ),
                );
              },
            )),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  SocialLoginButton(
                    type: SocialLoginType.apple,
                    onTap: () {
                      // Apple login
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
                      // Kakao login
                      ref
                          .read(authControllerProvider.notifier)
                          .signInWithKakao();
                    },
                  ),
                ],
              ),
            ),
            SizedBox(height: 16),
          ],
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

class UnchinLoginHeader extends StatelessWidget {
  const UnchinLoginHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '운친',
            style: AppTextStyle.headlineXLargeStyle.copyWith(
              color: AppColors.textDefault,
            ),
          ),

          const SizedBox(height: 10),

          RichText(
            text: TextSpan(
              style: AppTextStyle.titleSmallMediumStyle.copyWith(
                color: AppColors.textSecondary,
              ),
              children: [
                TextSpan(
                  text: '운',
                  style: AppTextStyle.titleSmallBoldStyle.copyWith(
                    color: AppColors.textDefault,
                  ),
                ),
                const TextSpan(text: '동에 미'),
                TextSpan(
                  text: '친',
                  style: AppTextStyle.titleSmallBoldStyle.copyWith(
                    color: AppColors.textDefault,
                  ),
                ),
                const TextSpan(text: ', '),
                TextSpan(
                  text: '운',
                  style: AppTextStyle.titleSmallBoldStyle.copyWith(
                    color: AppColors.textDefault,
                  ),
                ),
                const TextSpan(text: '동 '),

                TextSpan(
                  text: '친',
                  style: AppTextStyle.titleSmallBoldStyle.copyWith(
                    color: AppColors.textDefault,
                  ),
                ),
                const TextSpan(text: '구 만들기'),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // 보조 문장(2줄까지 자연스럽게)
          Text(
            '오늘 같이 뛸 사람을\n가볍게 찾아보세요.',
            style: AppTextStyle.headlineSmallMediumStyle.copyWith(
              color: AppColors.textDefault,
            ),
          ),
        ],
      ),
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
