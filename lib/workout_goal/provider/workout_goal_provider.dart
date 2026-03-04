import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:hellchinza/utils/date_time_util.dart';

import '../../feed/domain/feed_model.dart';
import '../presentation/workout_goal_controller.dart';
import '../presentation/workout_goal_state.dart';

/// ✅ user 목표(주 n회)
final workoutGoalProvider = FutureProvider<int?>((ref) async {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return null;

  final snap = await FirebaseFirestore.instance.collection('users').doc(uid).get();
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
final myWeeklyOowFeedsProvider =
FutureProvider.family<List<FeedModel>, DateTime>((ref, anyDayInWeek) async {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return [];

  // ✅ weekStart/End는 00:00 기준이 되도록(너 util이 이미 그러면 문제 없음)
  final weekStart = DateTimeUtil.startOfWeekMonday(anyDayInWeek);
  final weekEnd = weekStart.add(const Duration(days: 7));

  try {
    final q = FirebaseFirestore.instance
        .collection('feeds')
        .where('authorUid', isEqualTo: uid)
        .where('mainType', isEqualTo: '오운완')
        .where('meetId', isNull: true)
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(weekStart))
        .where('createdAt', isLessThan: Timestamp.fromDate(weekEnd))
        .orderBy('createdAt', descending: true);

    final snap = await q.get();
    return snap.docs.map((d) => FeedModel.fromJson(d.data())).toList();
  } catch (e) {
    // ✅ 인덱스 미생성/권한 등 에러가 떠도 앱이 죽지 않게
    return [];
  }
});

final workoutGoalControllerProvider =
StateNotifierProvider.autoDispose<WorkoutGoalController, WorkoutGoalState>(
      (ref) => WorkoutGoalController(ref),
);