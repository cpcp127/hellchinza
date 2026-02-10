import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';

class CommonFadeWidget extends StatelessWidget {
  final Widget child;
  final Duration? duration;
  final Duration? delay;

  const CommonFadeWidget(
      {super.key, required this.child, this.duration, this.delay});

  @override
  Widget build(BuildContext context) {
    return FadeIn(
      duration: duration ?? const Duration(milliseconds: 500),
      delay: delay ?? Duration.zero,
      child: child,
    );
  }
}
