import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:hellchinza/utils/date_time_util.dart';

import '../../feed/domain/feed_model.dart';
import '../domain/week_oow_stat_model.dart';
import '../provider/workout_goal_provider.dart';
import 'workout_goal_state.dart';

class WorkoutGoalController extends StateNotifier<WorkoutGoalState> {
  WorkoutGoalController(this.ref) : super(WorkoutGoalState.initial());

  final Ref ref;

  Future<void> init({DateTime? anyDayInWeek}) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final day = anyDayInWeek ?? DateTime.now();

      final goal = await ref.read(workoutGoalProvider.future);
      final feeds = await ref.read(myWeeklyOowFeedsProvider(day).future);

      // ✅ 날짜별로 묶기 (하루 여러개 OK)
      final map = <String, List<FeedModel>>{};
      for (final f in feeds) {
        final c = f.createdAt; // DateTime
        final d = DateTime(c.year, c.month, c.day);
        final k = DateTimeUtil.dateKey(d);
        (map[k] ??= []).add(f);
      }

      // ✅ “운동한 날 수” = 날짜 key 개수
      final doneDays = map.keys.length;

      // ✅ 선택 날짜 기본값
      final weekStart = DateTimeUtil.startOfWeekMonday(day);
      final weekEnd = weekStart.add(const Duration(days: 7));
      final today = DateTime.now();
      final todayDay = DateTime(today.year, today.month, today.day);

      final defaultSelected =
      (todayDay.isBefore(weekStart) || !todayDay.isBefore(weekEnd))
          ? weekStart
          : todayDay;

      state = state.copyWith(
        isLoading: false,
        errorMessage: null,
        goalPerWeek: goal,
        weekFeeds: feeds,
        weekMap: map,
        doneDays: doneDays,
        selectedDay: defaultSelected,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: '불러오기에 실패했어요',
      );
    }
  }

  void selectDay(DateTime d) {
    state = state.copyWith(selectedDay: DateTime(d.year, d.month, d.day));
  }

  Future<void> refresh() async {
    await init(anyDayInWeek: state.selectedDay);
  }

  /// ✅ 목표 저장 + 즉시 state 반영 + 화면 갱신
  Future<void> setWeeklyGoal(int target) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final userRef = FirebaseFirestore.instance.collection('users').doc(uid);

      await userRef.set({
        'workoutGoal': {
          'weeklyTarget': target,
          'updatedAt': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
        }
      }, SetOptions(merge: true));

      // ✅ 1) state에 목표 반영
      state = state.copyWith(
        isLoading: false,
        errorMessage: null,
        goalPerWeek: target,
      );

      // ✅ 2) 현재 선택 주 기준으로 다시 init 해서 UI 싱크
      await init(anyDayInWeek: state.selectedDay);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  // ---------- 최근 5주 집계 ----------
  Future<void> loadLast5Weeks() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final target = await ref.read(workoutGoalProvider.future);
      if (target == null || target <= 0) {
        state = state.copyWith(isLoading: false, last5Weeks: []);
        return;
      }

      final now = DateTime.now();
      final thisMon = DateTimeUtil.startOfWeekMonday(now);
      final start = thisMon.subtract(const Duration(days: 7 * 4));
      final end = thisMon.add(const Duration(days: 7));

      final q = FirebaseFirestore.instance
          .collection('feeds')
          .where('authorUid', isEqualTo: uid)
          .where('mainType', isEqualTo: '오운완')
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('createdAt', isLessThan: Timestamp.fromDate(end))
          .orderBy('createdAt', descending: false);

      final snap = await q.get();

      final Map<String, Set<String>> weekToDaySet = {};

      for (final doc in snap.docs) {
        final data = doc.data() as Map<String, dynamic>;

        final ts = data['createdAt'];
        DateTime createdAt;
        if (ts is Timestamp) {
          createdAt = ts.toDate();
        } else if (ts is DateTime) {
          createdAt = ts;
        } else {
          continue;
        }

        final day = DateTimeUtil.startOfDay(createdAt);
        final dk = DateTimeUtil.dayKey(day);

        final wkMon = DateTimeUtil.startOfWeekMonday(day);
        final wk = DateTimeUtil.weekKey(wkMon);

        (weekToDaySet[wk] ??= <String>{}).add(dk);
      }

      final weeks = <WeekOowStat>[];
      for (int i = 4; i >= 0; i--) {
        final mon = thisMon.subtract(Duration(days: 7 * i));
        final wk = DateTimeUtil.weekKey(mon);
        final doneDays = (weekToDaySet[wk]?.length ?? 0);

        weeks.add(
          WeekOowStat(
            weekStartMonday: mon,
            doneDays: doneDays,
            achieved: doneDays >= target,
          ),
        );
      }

      state = state.copyWith(isLoading: false, last5Weeks: weeks);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }
}