import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hellchinza/common/common_chip.dart';
import 'package:hellchinza/workout_goal/presentation/workout_goal_controller.dart';

import '../../constants/app_colors.dart';
import '../../constants/app_text_style.dart';
import '../provider/workout_goal_provider.dart';

class WorkoutGoalSetupView extends ConsumerStatefulWidget {
  const WorkoutGoalSetupView({super.key});

  @override
  ConsumerState<WorkoutGoalSetupView> createState() =>
      _WorkoutGoalSetupViewState();
}

class _WorkoutGoalSetupViewState
    extends ConsumerState<WorkoutGoalSetupView> {
  int selected = 3;

  @override
  Widget build(BuildContext context) {
    final controller =
    ref.read(workoutGoalControllerProvider.notifier);

    return Scaffold(

      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '일주일에 몇 번 운동할 건가요?',
              style: AppTextStyle.headlineSmallBoldStyle,
            ),
            const SizedBox(height: 24),

            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List.generate(7, (index) {
                final value = index + 1;

                final isSelected = selected == value;
                return CommonChip(label: '$value회', selected: isSelected,onTap: (){
                  setState(() {
                    selected = value;
                  });
                },);
              }),
            ),

            const Spacer(),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () async {
                  await controller.setWeeklyGoal(selected);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.btnPrimary,
                ),
                child: Text(
                  '목표 설정하기',
                  style: AppTextStyle.titleMediumBoldStyle
                      .copyWith(color: AppColors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}