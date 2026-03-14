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

  Future<void> init({
    required String uid,
    DateTime? anyDayInWeek,
  }) async {
    state = state.copyWith(
      isLoading: true,
      errorMessage: null,
      targetUid: uid,
    );

    try {
      final day = anyDayInWeek ?? DateTime.now();

      final goal = await ref.read(workoutGoalProvider(uid).future);
      final feeds = await ref.read(
        userWeeklyOowFeedsProvider(
          (uid: uid, anyDayInWeek: day),
        ).future,
      );

      final map = <String, List<FeedModel>>{};
      for (final f in feeds) {
        final c = f.createdAt;
        final d = DateTime(c.year, c.month, c.day);
        final k = DateTimeUtil.dateKey(d);
        (map[k] ??= []).add(f);
      }

      final doneDays = map.keys.length;

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
        targetUid: uid,
        goalPerWeek: goal,
        weekFeeds: feeds,
        weekMap: map,
        doneDays: doneDays,
        selectedDay: defaultSelected,
      );

      await loadLast5Weeks(uid: uid);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: '불러오기에 실패했어요',
      );
    }
  }

  void selectDay(DateTime d) {
    state = state.copyWith(
      selectedDay: DateTime(d.year, d.month, d.day),
    );
  }

  Future<void> refresh() async {
    final uid = state.targetUid;
    if (uid == null) return;

    await init(
      uid: uid,
      anyDayInWeek: state.selectedDay,
    );
  }

  /// ✅ 목표 저장은 "내 페이지"에서만 사용한다고 가정
  Future<void> setWeeklyGoal(int target) async {
    //final uid = state.targetUid;
    final myUid = FirebaseAuth.instance.currentUser?.uid;


    state = state.copyWith(
      isLoading: true,
      errorMessage: null,
    );

    try {
      final userRef = FirebaseFirestore.instance.collection('users').doc(myUid);

      await userRef.set({
        'workoutGoal': {
          'weeklyTarget': target,
          'updatedAt': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
        },
      }, SetOptions(merge: true));

      state = state.copyWith(
        isLoading: false,
        errorMessage: null,
        goalPerWeek: target,
      );
      ref.invalidate(workoutGoalProvider(FirebaseAuth.instance.currentUser!.uid));
      // await init(
      //   uid: myUid!,
      //   anyDayInWeek: state.selectedDay,
      // );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> loadLast5Weeks({
    required String uid,
  }) async {
    state = state.copyWith(
      isLoading: true,
      errorMessage: null,
    );

    try {
      final target = await ref.read(workoutGoalProvider(uid).future);

      if (target == null || target <= 0) {
        state = state.copyWith(
          isLoading: false,
          last5Weeks: [],
          last5WeeksSubTypeCount: {},
        );
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
          .where(
        'createdAt',
        isGreaterThanOrEqualTo: Timestamp.fromDate(start),
      )
          .where(
        'createdAt',
        isLessThan: Timestamp.fromDate(end),
      )
          .orderBy('createdAt', descending: false);

      final snap = await q.get();

      final Map<String, Set<String>> weekToDaySet = {};
      final Map<String, int> subTypeCount = {};

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

        final subType = (data['subType'] ?? '').toString().trim();
        if (subType.isNotEmpty && subType != '전체') {
          subTypeCount[subType] = (subTypeCount[subType] ?? 0) + 1;
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
        final doneDays = weekToDaySet[wk]?.length ?? 0;

        weeks.add(
          WeekOowStat(
            weekStartMonday: mon,
            doneDays: doneDays,
            achieved: doneDays >= target,
          ),
        );
      }

      state = state.copyWith(
        isLoading: false,
        last5Weeks: weeks,
        last5WeeksSubTypeCount: subTypeCount,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
    }
  }
}