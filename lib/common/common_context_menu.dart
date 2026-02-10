import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/app_text_style.dart';

class CommonContextMenuItem {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDestructive;

  const CommonContextMenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isDestructive = false,
  });
}


class CommonContextMenu {
  static void show({
    required BuildContext context,
    required Offset position,
    required List<CommonContextMenuItem> items,
    double width = 150,
  }) {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (_) => GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => entry.remove(),
        child: Stack(
          children: [
            // 배경 딤
            Container(color: Colors.black.withOpacity(0.15)),

            // 메뉴
            Positioned(
              left: position.dx,
              top: position.dy,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  width: width,
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.bgWhite,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x22000000),
                        blurRadius: 12,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: items.map((e) {
                      final color = e.isDestructive
                          ? AppColors.textError
                          : AppColors.textDefault;

                      return GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onTap: () {
                          entry.remove();
                          e.onTap();
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          child: Row(
                            children: [
                              Icon(e.icon, size: 18, color: color),
                              const SizedBox(width: 8),
                              Text(
                                e.label,
                                style: AppTextStyle.labelMediumStyle.copyWith(
                                  color: color,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    overlay.insert(entry);
  }
}
