import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../constants/app_colors.dart';
import '../../../../../constants/app_text_style.dart';
import '../../providers/oow_provider.dart';
import '../oow_step_controller.dart';
import 'oow_step_shell.dart';

class OowTopWorkoutStepPage extends ConsumerWidget {
  const OowTopWorkoutStepPage({super.key, required this.uid});

  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(oowStepControllerProvider(uid));
    final items = state.topWorkouts;

    final maxCount = items.isEmpty
        ? 1
        : items.map((e) => e.count).reduce((a, b) => a > b ? a : b);

    return OowStepShell(
      step: 5,
      title: '가장 많이 한 운동',
      subTitle: '최근 5주 동안 어떤 운동을 가장 자주 했는지 보여줘요',
      child: items.isEmpty
          ? Center(
              child: Text(
                '집계할 운동 데이터가 없어요',
                style: AppTextStyle.bodyMediumStyle.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            )
          : ListView.separated(
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                final item = items[index];
                final ratio = item.count / maxCount;

                return TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: ratio),
                  duration: Duration(milliseconds: 300 + (index * 120)),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, _) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                item.name,
                                style: AppTextStyle.titleSmallBoldStyle,
                              ),
                            ),
                            Text(
                              '${item.count}회',
                              style: AppTextStyle.labelSmallStyle.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            minHeight: 12,
                            value: value,
                            backgroundColor: AppColors.bgSecondary,
                            valueColor: AlwaysStoppedAnimation(
                              AppColors.btnPrimary,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
    );
  }
}
