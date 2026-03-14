import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:hellchinza/utils/date_time_util.dart';

import '../../feed/domain/feed_model.dart';
import '../presentation/workout_goal_controller.dart';
import '../presentation/workout_goal_state.dart';

/// ✅ user 목표(주 n회)
final workoutGoalProvider =
FutureProvider.family<int?, String>((ref, uid) async {
  final snap =
  await FirebaseFirestore.instance.collection('users').doc(uid).get();

  final data = snap.data();
  if (data == null) return null;

  final goalMap = (data['workoutGoal'] as Map?)?.cast<String, dynamic>();
  if (goalMap == null) return null;

  final v = goalMap['weeklyTarget'];
  if (v is int) return v;
  if (v is num) return v.toInt();
  return null;
});

/// ✅ 이번 주 내 오운완 피드(개인) 전부 가져오기
final userWeeklyOowFeedsProvider =
FutureProvider.family<List<FeedModel>, ({String uid, DateTime anyDayInWeek})>(
      (ref, param) async {
    final uid = param.uid;
    final anyDayInWeek = param.anyDayInWeek;

    final weekStart = DateTimeUtil.startOfWeekMonday(anyDayInWeek);
    final weekEnd = weekStart.add(const Duration(days: 7));

    try {
      final q = FirebaseFirestore.instance
          .collection('feeds')
          .where('authorUid', isEqualTo: uid)
          .where('mainType', isEqualTo: '오운완')
          .where('meetId', isNull: true)
          .where(
        'createdAt',
        isGreaterThanOrEqualTo: Timestamp.fromDate(weekStart),
      )
          .where(
        'createdAt',
        isLessThan: Timestamp.fromDate(weekEnd),
      )
          .orderBy('createdAt', descending: true);

      final snap = await q.get();
      return snap.docs.map((d) => FeedModel.fromJson(d.data())).toList();
    } catch (e) {
      return [];
    }
  },
);

final workoutGoalControllerProvider =
StateNotifierProvider<WorkoutGoalController, WorkoutGoalState>(
      (ref) => WorkoutGoalController(ref),
);