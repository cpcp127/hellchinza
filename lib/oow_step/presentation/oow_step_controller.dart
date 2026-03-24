import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../data/oow_step_repo.dart';
import 'oow_step_state.dart';

class OowStepController extends StateNotifier<OowStepState> {
  OowStepController({
    required OowStepRepo repo,
    required String uid,
  })  : _repo = repo,
        _uid = uid,
        super(OowStepState.initial());

  final OowStepRepo _repo;
  final String _uid;

  Future<void> init() async {
    state = state.copyWith(
      isLoading: true,
      clearError: true,
    );

    try {
      final result = await _repo.fetchAll(_uid);

      state = state.copyWith(
        isLoading: false,
        weeklyTarget: result.weeklyTarget,
        doneDays: result.doneDays,
        goalProgress: result.goalProgress,
        weekStart: result.weekStart,
        selectedDay: result.selectedDay,
        weekMap: result.weekMap,
        selectedDayFeeds: result.selectedDayFeeds,
        last5Weeks: result.last5Weeks,
        topWorkouts: result.topWorkouts,
        last5WeekMapByWeekKey: result.last5WeekMapByWeekKey,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> refresh() async {
    await init();
  }

  void changePage(int page) {
    state = state.copyWith(currentPage: page);
  }

  void selectDay(DateTime day) {
    final normalized = DateTime(day.year, day.month, day.day);
    final key = _dateKey(normalized);

    state = state.copyWith(
      selectedDay: normalized,
      selectedDayFeeds: state.weekMap[key] ?? const [],
    );
  }

  void selectWeek(DateTime weekStart) {
    final normalizedWeekStart = DateTime(
      weekStart.year,
      weekStart.month,
      weekStart.day,
    );

    final weekKey = _dateKey(normalizedWeekStart);
    final weekMap = state.last5WeekMapByWeekKey[weekKey] ?? const {};

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final currentWeekKey = _dateKey(_startOfWeekMonday(today));

    final selectedDay = currentWeekKey == weekKey
        ? (weekMap.containsKey(_dateKey(today)) ? today : normalizedWeekStart)
        : normalizedWeekStart;

    state = state.copyWith(
      weekStart: normalizedWeekStart,
      selectedDay: selectedDay,
      weekMap: weekMap,
      selectedDayFeeds: weekMap[_dateKey(selectedDay)] ?? const [],
    );
  }

  DateTime _startOfWeekMonday(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    return d.subtract(Duration(days: d.weekday - 1));
  }

  String _dateKey(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    return '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }
}