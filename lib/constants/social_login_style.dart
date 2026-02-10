import 'dart:ui';

import 'app_colors.dart';

enum SocialLoginType {
  apple,
  google,
  naver,
  kakao,
}
class SocialLoginStyle {
  final Color background;
  final Color textColor;
  final Color iconColor;
  final Color? borderColor;
  final String assetPath;

  const SocialLoginStyle({
    required this.background,
    required this.textColor,
    required this.iconColor,
    required this.assetPath,
    this.borderColor,
  });

  static SocialLoginStyle of(SocialLoginType type) {
    switch (type) {
      case SocialLoginType.apple:
        return SocialLoginStyle(
          background: AppColors.black,
          textColor: AppColors.white,
          iconColor: AppColors.white,
          assetPath: 'assets/images/icon/btn_apple.svg',
        );

      case SocialLoginType.google:
        return SocialLoginStyle(
          background: AppColors.white,
          textColor: AppColors.textDefault,
          iconColor: AppColors.textDefault,
          borderColor: AppColors.borderSecondary,
          assetPath: 'assets/images/icon/btn_google.svg',
        );

      case SocialLoginType.naver:
        return SocialLoginStyle(
          background: const Color(0xFF03C75A),
          textColor: AppColors.white,
          iconColor: AppColors.white,
          assetPath: 'assets/images/icon/btn_naver.svg'
        );

      case SocialLoginType.kakao:
        return SocialLoginStyle(
          background: const Color(0xFFFEE500),
          textColor: AppColors.black,
          iconColor: AppColors.black,
          assetPath: 'assets/images/icon/btn_kakao.svg'
        );
    }
  }
}
