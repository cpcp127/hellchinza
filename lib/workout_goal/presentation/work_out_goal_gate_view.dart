import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hellchinza/workout_goal/presentation/workout_goal_root_view.dart';
import 'package:hellchinza/workout_goal/presentation/workout_goal_setup_view.dart';

import '../provider/workout_goal_provider.dart';

class WorkoutGoalGateView extends ConsumerWidget {
  const WorkoutGoalGateView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workoutGoalAsync = ref.watch(workoutGoalProvider(FirebaseAuth.instance.currentUser!.uid));

    return workoutGoalAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        body: Center(child: Text('목표 정보를 불러오지 못했어요')),
      ),
      data: (goal) {
        final weeklyTarget = goal ?? 0;

        if (weeklyTarget <= 0) {
          return const WorkoutGoalSetupView();
        }

        return WorkoutGoalRootView(uid: FirebaseAuth.instance.currentUser!.uid); // 기존 오운완 메인 화면
      },
    );
  }
}