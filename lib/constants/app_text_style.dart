import 'package:flutter/material.dart';

import 'app_colors.dart';

const String _fontFamily = 'Pretendard';

class AppTextStyle {
  const AppTextStyle._();

  static TextStyle _textStyle = TextStyle(
    color: AppColors.textDefault,
    fontFamily: _fontFamily,
    fontStyle: FontStyle.normal,
  );

  // ------------ base typo style ------------------

  static final TextStyle headlineXLargeStyle = _textStyle.copyWith(
    fontWeight: FontWeight.w700,
    fontSize: 24,
    height: 34 / 24,
    letterSpacing: -0.2,
  );

  static final TextStyle headlineLargeStyle = _textStyle.copyWith(
    fontWeight: FontWeight.w700,
    fontSize: 22,
    height: 31 / 22,
    letterSpacing: -0.2,
  );

  static final TextStyle headlineMediumStyle = _textStyle.copyWith(
    fontWeight: FontWeight.w700,
    fontSize: 20,
    height: 28 / 20,
    letterSpacing: -0.2,
  );

  static final TextStyle headlineSmallBoldStyle = _textStyle.copyWith(
    fontWeight: FontWeight.w700,
    fontSize: 18,
    height: 25 / 18,
    letterSpacing: -0.2,
  );
  static final TextStyle headlineSmallMediumStyle = _textStyle.copyWith(
    fontWeight: FontWeight.w500,
    fontSize: 18,
    height: 25 / 18,
    letterSpacing: -0.2,
  );
  static final TextStyle headlineMediumBoldStyle = _textStyle.copyWith(
    fontWeight: FontWeight.w700,
    fontSize: 20,
    height: 28 / 20,
    letterSpacing: -0.2,
  );
  static final TextStyle titleMediumBoldStyle = _textStyle.copyWith(
    fontWeight: FontWeight.w700,
    fontSize: 16,
    height: 24 / 16,
    letterSpacing: -0.2,
  );

  static final TextStyle titleMediumStyle = _textStyle.copyWith(
    fontWeight: FontWeight.w500,
    fontSize: 16,
    height: 24 / 16,
    letterSpacing: -0.2,
  );

  static final TextStyle titleSmallBoldStyle = _textStyle.copyWith(
    fontWeight: FontWeight.w700,
    fontSize: 14,
    height: 21 / 14,
    letterSpacing: -0.2,
  );

  static final TextStyle titleSmallMediumStyle = _textStyle.copyWith(
    fontWeight: FontWeight.w500,
    fontSize: 14,
    height: 21 / 14,
    letterSpacing: -0.2,
  );

  static final TextStyle bodyLargeStyle = _textStyle.copyWith(
    fontWeight: FontWeight.w400,
    fontSize: 16,
    height: 26 / 16,
    letterSpacing: -0.2,
  );

  static final TextStyle bodyMediumStyle = _textStyle.copyWith(
    fontWeight: FontWeight.w400,
    fontSize: 14,
    height: 21 / 14,
    letterSpacing: -0.2,
  );

  static final TextStyle bodySmallStyle = _textStyle.copyWith(
    fontWeight: FontWeight.w400,
    fontSize: 12,
    height: 18 / 12,
    letterSpacing: -0.2,
  );

  static final TextStyle labelLargeStyle = _textStyle.copyWith(
    fontWeight: FontWeight.w500,
    fontSize: 16,
    height: 24 / 16,
    letterSpacing: -0.2,
  );

  static final TextStyle labelMediumStyle = _textStyle.copyWith(
    fontWeight: FontWeight.w500,
    fontSize: 14,
    height: 21 / 14,
    letterSpacing: -0.2,
  );

  static final TextStyle labelSmallStyle = _textStyle.copyWith(
    fontWeight: FontWeight.w500,
    fontSize: 12,
    height: 18 / 12,
    letterSpacing: -0.2,
  );

  static final TextStyle labelXSmallStyle = _textStyle.copyWith(
    fontWeight: FontWeight.w500,
    fontSize: 10,
    height: 15 / 10,
    letterSpacing: -0.2,
  );

  static final TextStyle notSetStyle = _textStyle.copyWith(
    fontWeight: FontWeight.w300,
    fontSize: 40,
    height: 52 / 40,
    letterSpacing: -0.2,
  );
}
