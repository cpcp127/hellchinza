import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/app_text_style.dart';

class CommonBackAppbar extends StatelessWidget implements PreferredSizeWidget {
  final String? title;
  final VoidCallback? onBack;
  final List<Widget>? actions;

  const CommonBackAppbar({super.key, this.actions, this.title, this.onBack});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      leading: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: onBack ?? () => Navigator.pop(context),
        child: const Center(
          child: Icon(
            Icons.arrow_back_ios_new,
            size: 20,
            color: AppColors.icDefault, // gray900
          ),
        ),
      ),
      title: title == null ? null : Text(title!),

      actions: actions,
    );
  }
}
class CommonCloseAppbar extends StatelessWidget implements PreferredSizeWidget {
  final String? title;
  final VoidCallback? onClose;
  final List<Widget>? actions;
  final Color? backgroundColor;
  const CommonCloseAppbar({super.key, this.actions, this.title, this.onClose,this.backgroundColor});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: backgroundColor ?? Colors.white,
      leading: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: onClose ?? () => Navigator.pop(context),
        child: const Center(
          child: Icon(
            Icons.close,
            size: 20,
            color: AppColors.icDefault, // gray900
          ),
        ),
      ),
      title: title == null ? null : Text(title!),

      actions: actions,
    );
  }
}
