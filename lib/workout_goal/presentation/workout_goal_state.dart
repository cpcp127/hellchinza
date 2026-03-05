import '../../feed/domain/feed_model.dart';
import '../domain/week_oow_stat_model.dart';

class WorkoutGoalState {
  final bool isLoading;
  final String? errorMessage;

  final int? goalPerWeek;

  /// 이번 주 오운완 피드 전체(하루 여러개 가능)
  final List<FeedModel> weekFeeds;

  /// key=yyyyMMdd, value=그날 피드들
  final Map<String, List<FeedModel>> weekMap;

  /// ✅ 운동한 날 수(그날 오운완이 1개라도 있으면 1)
  final int doneDays;

  /// 현재 선택 날짜
  final DateTime selectedDay;

  final List<WeekOowStat> last5Weeks;
  final Map<String, int> last5WeeksSubTypeCount; // ✅ 최근 5주 subType 집계
  const WorkoutGoalState({
    required this.isLoading,
    required this.errorMessage,
    required this.goalPerWeek,
    required this.weekFeeds,
    required this.weekMap,
    required this.doneDays,
    required this.selectedDay,
    required this.last5Weeks,
    required this.last5WeeksSubTypeCount,
  });

  factory WorkoutGoalState.initial() {
    final now = DateTime.now();
    return WorkoutGoalState(
      isLoading: false,
      errorMessage: null,
      goalPerWeek: null,
      weekFeeds: const [],
      weekMap: const {},
      doneDays: 0,
      selectedDay: DateTime(now.year, now.month, now.day),
      last5Weeks: [],
      last5WeeksSubTypeCount: {},
    );
  }

  WorkoutGoalState copyWith({
    bool? isLoading,
    String? errorMessage,
    int? goalPerWeek,
    List<FeedModel>? weekFeeds,
    Map<String, List<FeedModel>>? weekMap,
    int? doneDays,
    DateTime? selectedDay,
    List<WeekOowStat>? last5Weeks,
    Map<String, int>? last5WeeksSubTypeCount,
  }) {
    return WorkoutGoalState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      goalPerWeek: goalPerWeek ?? this.goalPerWeek,
      weekFeeds: weekFeeds ?? this.weekFeeds,
      weekMap: weekMap ?? this.weekMap,
      doneDays: doneDays ?? this.doneDays,
      selectedDay: selectedDay ?? this.selectedDay,
      last5Weeks: last5Weeks ?? this.last5Weeks,
      last5WeeksSubTypeCount:
          last5WeeksSubTypeCount ?? this.last5WeeksSubTypeCount,
    );
  }
}
