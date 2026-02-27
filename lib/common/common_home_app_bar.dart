import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/app_text_style.dart';

class CommonHomeAppbar extends StatelessWidget
    implements PreferredSizeWidget {
  const CommonHomeAppbar({
    super.key,
    required this.title,
    this.actions,
    this.leading,
    this.showBackButton = true,
  });

  final String title;
  final List<Widget>? actions;
  final Widget? leading;
  final bool showBackButton;

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();

    return AppBar(
      automaticallyImplyLeading: false,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      backgroundColor: AppColors.bgWhite,
      centerTitle: false, // ✅ 왼쪽 정렬

      leading: leading ??
          (showBackButton && canPop
              ? IconButton(
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 20,
              color: AppColors.icDefault,
            ),
            onPressed: () => Navigator.pop(context),
          )
              : null),

      titleSpacing: 0, // ✅ 완전 왼쪽 붙이기
      title: Padding(
        padding: const EdgeInsets.only(left: 16),
        child: Text(
          title,
          style: AppTextStyle.headlineLargeStyle.copyWith(
            // 22px → 요즘 앱 느낌
            fontWeight: FontWeight.w800,
            color: AppColors.textDefault,
          ),
        ),
      ),

      actions: actions,
    );
  }
}