import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/app_text_style.dart';

class CommonTextField extends StatefulWidget {
  final TextEditingController controller;
  final String? hintText;
  final int? minLines;
  final int? maxLines;
  final int? maxLength;
  final bool obscureText;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;
  final bool enabled;
  final Widget? suffixIcon;

  final double? scrollPadding;
  const CommonTextField({
    super.key,
    required this.controller,
    this.hintText,
    this.minLines = 1,
    this.maxLines = 1,
    this.maxLength,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.validator,
    this.onChanged,
    this.enabled = true,this.scrollPadding,this.suffixIcon,
  });

  @override
  State<CommonTextField> createState() => _CommonTextFieldState();
}

class _CommonTextFieldState extends State<CommonTextField> {
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  OutlineInputBorder _border({
    required Color color,
    required double width,
  }) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: color, width: width),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hintStyle = AppTextStyle.bodyMediumStyle.copyWith(
      color: AppColors.textLabel,
    );

    final textStyle = AppTextStyle.bodyMediumStyle.copyWith(
      color: AppColors.textDefault,
    );

    return TextFormField(
      controller: widget.controller,
      focusNode: _focusNode,
      minLines: widget.minLines,
      maxLines: widget.maxLines,
      maxLength: widget.maxLength,
      obscureText: widget.obscureText,
      keyboardType: widget.keyboardType,
      validator: widget.validator,
      onChanged: widget.onChanged,
      enabled: widget.enabled,
      style: textStyle,
      scrollPadding: EdgeInsets.only(
        bottom: widget.scrollPadding ?? 0,
      ),
      cursorColor: AppColors.borderPrimary,
      decoration: InputDecoration(
        // ✅ validator는 정상 작동, 에러 텍스트만 숨김
        errorStyle: const TextStyle(fontSize: 0, height: 0),
        hintText: widget.hintText,
        hintStyle: hintStyle,
        counterText:
        widget.maxLength==null?'':
        '${widget.controller!.text.length} / ${widget.maxLength}',
        counterStyle: AppTextStyle.labelSmallStyle,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),

        // 기본
        enabledBorder: _border(
          color: AppColors.borderSecondary,
          width: 1,
        ),

        // 포커스
        focusedBorder: _border(
          color: AppColors.borderPrimary,
          width: 2,
        ),

        // 에러
        errorBorder: _border(
          color: AppColors.borderError,
          width: 2,
        ),
        focusedErrorBorder: _border(
          color: AppColors.borderError,
          width: 2,
        ),

        // 비활성
        disabledBorder: _border(
          color: AppColors.borderTertiary,
          width: 1,
        ),
        suffixIcon: widget.suffixIcon,
      ),
    );
  }
}


