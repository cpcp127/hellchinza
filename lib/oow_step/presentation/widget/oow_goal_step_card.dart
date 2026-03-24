import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../constants/app_colors.dart';
import '../../../../../constants/app_text_style.dart';
import '../../providers/oow_provider.dart';
import '../oow_step_controller.dart';
import 'oow_step_shell.dart';

class OowGoalStepPage extends ConsumerWidget {
  const OowGoalStepPage({
    super.key,
    required this.uid,
  });

  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(oowStepControllerProvider(uid));

    return OowStepShell(
      step: 2,
      title: '이번 주 목표',
      subTitle: '이번 주 운동 목표와 달성률을 확인해보세요',
      child: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: state.goalProgress),
                duration: const Duration(milliseconds: 1100),
                curve: Curves.easeOutCubic,
                builder: (context, value, _) {
                  return SizedBox(
                    width: 180,
                    height: 180,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CustomPaint(
                          size: const Size(180, 180),
                          painter: _ProgressPainter(value: value),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${(value * 100).round()}%',
                              style: AppTextStyle.headlineLargeStyle,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${state.doneDays} / ${state.weeklyTarget}회',
                              style: AppTextStyle.bodyMediumStyle.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 28),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: Text(
                  state.goalProgress >= 1
                      ? '이번 주 목표를 달성했어요'
                      : '목표까지 ${((state.weeklyTarget - state.doneDays) < 0 ? 0 : (state.weeklyTarget - state.doneDays))}회 남았어요',
                  key: ValueKey('${state.doneDays}-${state.weeklyTarget}'),
                  style: AppTextStyle.titleMediumBoldStyle,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProgressPainter extends CustomPainter {
  const _ProgressPainter({required this.value});

  final double value;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 12.0;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - stroke) / 2;

    final bgPaint = Paint()
      ..color = AppColors.bgSecondary
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    final fgPaint = Paint()
      ..color = AppColors.btnPrimary
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, bgPaint);

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      math.pi * 2 * value,
      false,
      fgPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _ProgressPainter oldDelegate) {
    return oldDelegate.value != value;
  }
}