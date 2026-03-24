import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../presentation/oow_step_state.dart';

class OowStepRepo {
  OowStepRepo({required FirebaseFirestore db}) : _db = db;

  final FirebaseFirestore _db;

  Future<
    ({
      int weeklyTarget,
      int doneDays,
      double goalProgress,
      DateTime weekStart,
      DateTime selectedDay,
      Map<String, List<OowFeedItem>> weekMap,
      List<OowFeedItem> selectedDayFeeds,
      List<OowWeekStat> last5Weeks,
      List<OowWorkoutStat> topWorkouts,
      Map<String, Map<String, List<OowFeedItem>>> last5WeekMapByWeekKey,
    })
  >
  fetchAll(String uid) async {
    final now = DateTime.now();
    final today = _startOfDay(now);
    final currentWeekStart = _startOfWeekMonday(today);

    final weeklyTarget = await _fetchWeeklyTarget(uid);
    final last5WeekFeeds = await _fetchRecent5WeekFeeds(uid, currentWeekStart);

    final last5WeekMapByWeekKey = _groupFeedsByWeekAndDay(last5WeekFeeds);

    final currentWeekKey = _dateKey(currentWeekStart);
    final weekMap = last5WeekMapByWeekKey[currentWeekKey] ?? const {};

    final doneDays = weekMap.keys.length;
    final goalProgress = weeklyTarget <= 0
        ? 0.0
        : (doneDays / weeklyTarget).clamp(0.0, 1.0);

    final selectedDay = weekMap.containsKey(_dateKey(today))
        ? today
        : currentWeekStart;
    final selectedDayFeeds = weekMap[_dateKey(selectedDay)] ?? const [];

    final last5Weeks = _buildLast5WeeksFromFeeds(
      last5WeekFeeds,
      weeklyTarget,
      currentWeekStart,
    );
    final topWorkouts = _buildTopWorkoutStats(last5WeekFeeds);

    return (
      weeklyTarget: weeklyTarget,
      doneDays: doneDays,
      goalProgress: goalProgress,
      weekStart: currentWeekStart,
      selectedDay: selectedDay,
      weekMap: weekMap,
      selectedDayFeeds: selectedDayFeeds,
      last5Weeks: last5Weeks,
      topWorkouts: topWorkouts,
      last5WeekMapByWeekKey: last5WeekMapByWeekKey,
    );
  }

  Future<int> _fetchWeeklyTarget(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    final data = doc.data();
    if (data == null) return 3;

    final workoutGoal = data['workoutGoal'];
    if (workoutGoal is Map<String, dynamic>) {
      final target = workoutGoal['weeklyTarget'];
      if (target is int) return target;
      if (target is num) return target.toInt();
    }
    return 3;
  }

  Future<List<OowFeedItem>> _fetchRecent5WeekFeeds(
    String uid,
    DateTime currentWeekStart,
  ) async {
    final oldestWeekStart = currentWeekStart.subtract(
      const Duration(days: 7 * 4),
    );
    final rangeEnd = currentWeekStart.add(const Duration(days: 7));

    final snap = await _db
        .collection('feeds')
        .where('authorUid', isEqualTo: uid)
        .where('mainType', isEqualTo: '오운완')
        .where(
          'createdAt',
          isGreaterThanOrEqualTo: Timestamp.fromDate(oldestWeekStart),
        )
        .where('createdAt', isLessThan: Timestamp.fromDate(rangeEnd))
        .orderBy('createdAt', descending: true)
        .get();

    return snap.docs.map(_toFeedItem).toList();
  }

  Map<String, Map<String, List<OowFeedItem>>> _groupFeedsByWeekAndDay(
    List<OowFeedItem> feeds,
  ) {
    final result = <String, Map<String, List<OowFeedItem>>>{};

    for (final feed in feeds) {
      final day = _startOfDay(feed.createdAt);
      final weekStart = _startOfWeekMonday(day);
      final weekKey = _dateKey(weekStart);
      final dayKey = _dateKey(day);

      result.putIfAbsent(weekKey, () => <String, List<OowFeedItem>>{});
      result[weekKey]!.putIfAbsent(dayKey, () => <OowFeedItem>[]);
      result[weekKey]![dayKey]!.add(feed);
    }

    return result;
  }

  List<OowWeekStat> _buildLast5WeeksFromFeeds(
    List<OowFeedItem> feeds,
    int weeklyTarget,
    DateTime currentWeekStart,
  ) {
    final map = <String, Set<String>>{};

    for (final feed in feeds) {
      final day = _startOfDay(feed.createdAt);
      final weekStart = _startOfWeekMonday(day);
      final weekKey = _dateKey(weekStart);

      map.putIfAbsent(weekKey, () => <String>{});
      map[weekKey]!.add(_dateKey(day));
    }

    final result = <OowWeekStat>[];
    for (int i = 4; i >= 0; i--) {
      final weekStart = currentWeekStart.subtract(Duration(days: 7 * i));
      final weekKey = _dateKey(weekStart);
      final doneDays = map[weekKey]?.length ?? 0;

      result.add(
        OowWeekStat(
          weekStart: weekStart,
          doneDays: doneDays,
          achieved: doneDays >= weeklyTarget,
        ),
      );
    }

    return result;
  }

  List<OowWorkoutStat> _buildTopWorkoutStats(List<OowFeedItem> feeds) {
    final countMap = <String, int>{};

    for (final feed in feeds) {
      final name = feed.subType.trim();
      if (name.isEmpty) continue;
      countMap[name] = (countMap[name] ?? 0) + 1;
    }

    final list =
        countMap.entries
            .map((e) => OowWorkoutStat(name: e.key, count: e.value))
            .toList()
          ..sort((a, b) {
            final countCompare = b.count.compareTo(a.count);
            if (countCompare != 0) return countCompare;
            return a.name.compareTo(b.name);
          });

    return list.take(5).toList();
  }

  OowFeedItem _toFeedItem(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};

    return OowFeedItem(
      id: doc.id,
      text: (data['contents'] ?? '').toString(),
      subType: (data['subType'] ?? '').toString(),
      createdAt: _toDateTime(data['createdAt']) ?? DateTime.now(),
      imageUrls: ((data['imageUrls'] as List?) ?? const [])
          .map((e) => e.toString())
          .toList(),
    );
  }

  DateTime? _toDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  DateTime _startOfDay(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  DateTime _startOfWeekMonday(DateTime date) {
    final d = _startOfDay(date);
    return d.subtract(Duration(days: d.weekday - 1));
  }

  String _dateKey(DateTime date) {
    final d = _startOfDay(date);
    return '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }
}

final oowStepRepoProvider = Provider<OowStepRepo>((ref) {
  return OowStepRepo(db: FirebaseFirestore.instance);
});
