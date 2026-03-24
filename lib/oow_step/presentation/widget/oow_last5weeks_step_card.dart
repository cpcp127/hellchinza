import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../constants/app_colors.dart';
import '../../../../../constants/app_text_style.dart';
import '../../providers/oow_provider.dart';
import '../oow_step_controller.dart';
import 'oow_step_shell.dart';

class OowLast5WeeksStepPage extends ConsumerWidget {
  const OowLast5WeeksStepPage({
    super.key,
    required this.uid,
  });

  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(oowStepControllerProvider(uid));
    final items = state.last5Weeks;

    const int scaleMax = 7;
    final targetDays = state.weeklyTarget.clamp(0, scaleMax);
    final targetRatio = targetDays / scaleMax;

    return OowStepShell(
      step: 4,
      title: '최근 5주 기록',
      subTitle: '최근 5주 동안 얼마나 꾸준히 운동했는지 확인해보세요',
      child: Column(
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final totalHeight = constraints.maxHeight;

                final valueLabelHeight = totalHeight * 0.12;
                final bottomLabelHeight = totalHeight * 0.12;
                final gap1 = totalHeight * 0.04;
                final gap2 = totalHeight * 0.04;

                final rawChartHeight = totalHeight -
                    valueLabelHeight -
                    bottomLabelHeight -
                    gap1 -
                    gap2;

                final chartHeight = rawChartHeight < 40 ? 40.0 : rawChartHeight;

                return Stack(
                  children: [
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: bottomLabelHeight + (chartHeight * targetRatio),
                      child: _DashedGuideLine(
                        label: '목표 ${state.weeklyTarget}일',
                      ),
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: items.asMap().entries.map((entry) {
                        final index = entry.key;
                        final item = entry.value;
                        final safeDoneDays = item.doneDays.clamp(0, scaleMax);
                        final ratio = safeDoneDays / scaleMax;

                        return Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(
                              right: index == items.length - 1 ? 0 : 10,
                            ),
                            child: Column(
                              children: [
                                SizedBox(
                                  height: valueLabelHeight,
                                  child: Align(
                                    alignment: Alignment.bottomCenter,
                                    child: Text(
                                      '${item.doneDays}일',
                                      style: AppTextStyle.labelSmallStyle.copyWith(
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(height: gap1),
                                SizedBox(
                                  height: chartHeight,
                                  child: Align(
                                    alignment: Alignment.bottomCenter,
                                    child: TweenAnimationBuilder<double>(
                                      tween: Tween(begin: 0, end: ratio),
                                      duration: Duration(
                                        milliseconds: 450 + index * 130,
                                      ),
                                      curve: Curves.easeOutCubic,
                                      builder: (context, value, _) {
                                        final barHeight =
                                        (chartHeight * value).clamp(
                                          10.0,
                                          chartHeight,
                                        );

                                        return Container(
                                          width: double.infinity,
                                          height: barHeight,
                                          decoration: BoxDecoration(
                                            color: item.achieved
                                                ? AppColors.btnPrimary
                                                : AppColors.bgSecondary,
                                            borderRadius:
                                            BorderRadius.circular(14),
                                            border: Border.all(
                                              color: item.achieved
                                                  ? AppColors.borderPrimary
                                                  : AppColors.borderSecondary,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                                SizedBox(height: gap2),
                                SizedBox(
                                  height: bottomLabelHeight,
                                  child: Align(
                                    alignment: Alignment.topCenter,
                                    child: Text(
                                      _weekLabel(item.weekStart),
                                      style: AppTextStyle.labelXSmallStyle.copyWith(
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 18,
                height: 10,
                decoration: BoxDecoration(
                  color: AppColors.btnPrimary,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '목표 달성',
                style: AppTextStyle.bodySmallStyle.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 18,
                height: 8,
                child: CustomPaint(
                  painter: _MiniDashPainter(),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '주간 목표선',
                style: AppTextStyle.bodySmallStyle.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _weekLabel(DateTime d) {
    return '${d.month}/${d.day}';
  }
}

class _DashedGuideLine extends StatelessWidget {
  const _DashedGuideLine({
    required this.label,
  });

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.bgWhite,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: AppColors.borderSecondary),
          ),
          child: Text(
            label,
            style: AppTextStyle.labelXSmallStyle.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
        const SizedBox(width: 8),
        const Expanded(
          child: SizedBox(
            height: 1,
            child: CustomPaint(
              painter: _DashLinePainter(),
            ),
          ),
        ),
      ],
    );
  }
}

class _DashLinePainter extends CustomPainter {
  const _DashLinePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.gray300
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    const dashWidth = 6.0;
    const dashSpace = 4.0;

    double startX = 0;
    while (startX < size.width) {
      canvas.drawLine(
        Offset(startX, size.height / 2),
        Offset(
          (startX + dashWidth).clamp(0, size.width),
          size.height / 2,
        ),
        paint,
      );
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _MiniDashPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.gray300
      ..strokeWidth = 1.2;

    const dashWidth = 4.0;
    const dashSpace = 3.0;

    double startX = 0;
    while (startX < size.width) {
      canvas.drawLine(
        Offset(startX, size.height / 2),
        Offset(
          (startX + dashWidth).clamp(0, size.width),
          size.height / 2,
        ),
        paint,
      );
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}