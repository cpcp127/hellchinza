import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/app_text_style.dart';
import '../main.dart';

import 'dart:async';
import 'package:flutter/material.dart';

enum AppSnackType {
  uploading,
  success,
  error,
}

class SnackbarService {
  const SnackbarService();

  static OverlayEntry? _entry;
  static Timer? _timer;

  /// 업로딩 progress 구독 해제용
  static VoidCallback? _removeProgressListener;

  static void show({
    required AppSnackType type,
    required String message,
    ValueListenable<double>? progress,
    Duration duration = const Duration(seconds: 2),
  }) {
    final nav = rootNavigatorKey.currentState;
    if (nav == null) return; // 앱 시작 직후 방어

    final overlayState = nav.overlay;
    if (overlayState == null) return;

    dismiss();

    _entry = OverlayEntry(
      builder: (ctx) {
        return _TopSnackOverlay(
          type: type,
          message: message,
          progress: progress,
          duration: duration,
        );
      },
    );

    overlayState.insert(_entry!);

    if (type != AppSnackType.uploading) {
      _timer = Timer(duration, () => dismiss());
    }
  }


  static void dismiss() {
    _timer?.cancel();
    _timer = null;

    _removeProgressListener?.call();
    _removeProgressListener = null;

    _entry?.remove();
    _entry = null;
  }
}

/// ✅ Overlay에 띄워질 실제 위젯 (터치 막지 않음)
class _TopSnackOverlay extends StatefulWidget {
  const _TopSnackOverlay({
    required this.type,
    required this.message,
    required this.progress,
    required this.duration,
  });

  final AppSnackType type;
  final String message;
  final ValueListenable<double>? progress;
  final Duration duration;

  @override
  State<_TopSnackOverlay> createState() => _TopSnackOverlayState();
}

class _TopSnackOverlayState extends State<_TopSnackOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );

    _slide = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = _SnackTheme.of(widget.type);

    // ✅ 핵심: IgnorePointer로 뒤 UI 터치 통과
    return IgnorePointer(
      ignoring: true,
      child: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: SlideTransition(
            position: _slide,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Material(
                color: Colors.transparent,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: theme.background,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x14000000),
                        blurRadius: 12,
                        offset: Offset(0, 4),
                      ),
                    ],
                    border: widget.type == AppSnackType.uploading
                        ? Border.all(color: AppColors.borderSecondary)
                        : null,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Icon(theme.icon, color: theme.iconColor, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              widget.message,
                              style: AppTextStyle.labelMediumStyle.copyWith(
                                color: theme.textColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (widget.type == AppSnackType.uploading &&
                          widget.progress != null) ...[
                        const SizedBox(height: 10),
                        ValueListenableBuilder<double>(
                          valueListenable: widget.progress!,
                          builder: (_, v, __) {
                            return LinearProgressIndicator(
                              value: v.clamp(0, 1),
                              minHeight: 4,
                              backgroundColor: theme.progressBg,
                              valueColor:
                              AlwaysStoppedAnimation(theme.progressFg),
                            );
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SnackTheme {
  final Color background;
  final Color textColor;
  final Color iconColor;
  final Color progressBg;
  final Color progressFg;
  final IconData icon;

  const _SnackTheme({
    required this.background,
    required this.textColor,
    required this.iconColor,
    required this.progressBg,
    required this.progressFg,
    required this.icon,
  });

  static _SnackTheme of(AppSnackType type) {
    switch (type) {
      case AppSnackType.uploading:
        return _SnackTheme(
          background: AppColors.bgWhite,
          textColor: AppColors.textDefault,
          iconColor: AppColors.icPrimary,
          progressBg: AppColors.gray100,
          progressFg: AppColors.sky400,
          icon: Icons.cloud_upload_outlined,
        );
      case AppSnackType.success:
        return _SnackTheme(
          background: AppColors.green10,
          textColor: AppColors.textDefault,
          iconColor: AppColors.green400,
          progressBg: Colors.transparent,
          progressFg: Colors.transparent,
          icon: Icons.check_circle_outline,
        );
      case AppSnackType.error:
        return _SnackTheme(
          background: AppColors.red10,
          textColor: AppColors.textDefault,
          iconColor: AppColors.textError,
          progressBg: Colors.transparent,
          progressFg: Colors.transparent,
          icon: Icons.error_outline,
        );
    }
  }
}
