class OowStepState {
  final bool isLoading;
  final String? errorMessage;
  final int currentPage;
  final int weeklyTarget;
  final int doneDays;
  final double goalProgress;
  final DateTime weekStart;
  final DateTime selectedDay;
  final Map<String, List<OowFeedItem>> weekMap;
  final List<OowFeedItem> selectedDayFeeds;
  final List<OowWeekStat> last5Weeks;
  final List<OowWorkoutStat> topWorkouts;
  final Map<String, Map<String, List<OowFeedItem>>> last5WeekMapByWeekKey;

  const OowStepState({
    this.isLoading = true,
    this.errorMessage,
    this.currentPage = 0,
    this.weeklyTarget = 0,
    this.doneDays = 0,
    this.goalProgress = 0,
    required this.weekStart,
    required this.selectedDay,
    this.weekMap = const {},
    this.selectedDayFeeds = const [],
    this.last5Weeks = const [],
    this.topWorkouts = const [],
    this.last5WeekMapByWeekKey = const {},
  });

  factory OowStepState.initial() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final monday = today.subtract(Duration(days: today.weekday - 1));
    return OowStepState(
      weekStart: monday,
      selectedDay: today,
    );
  }

  OowStepState copyWith({
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
    int? currentPage,
    int? weeklyTarget,
    int? doneDays,
    double? goalProgress,
    DateTime? weekStart,
    DateTime? selectedDay,
    Map<String, List<OowFeedItem>>? weekMap,
    List<OowFeedItem>? selectedDayFeeds,
    List<OowWeekStat>? last5Weeks,
    List<OowWorkoutStat>? topWorkouts,
    Map<String, Map<String, List<OowFeedItem>>>? last5WeekMapByWeekKey,
  }) {
    return OowStepState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      currentPage: currentPage ?? this.currentPage,
      weeklyTarget: weeklyTarget ?? this.weeklyTarget,
      doneDays: doneDays ?? this.doneDays,
      goalProgress: goalProgress ?? this.goalProgress,
      weekStart: weekStart ?? this.weekStart,
      selectedDay: selectedDay ?? this.selectedDay,
      weekMap: weekMap ?? this.weekMap,
      selectedDayFeeds: selectedDayFeeds ?? this.selectedDayFeeds,
      last5Weeks: last5Weeks ?? this.last5Weeks,
      topWorkouts: topWorkouts ?? this.topWorkouts,
      last5WeekMapByWeekKey:
      last5WeekMapByWeekKey ?? this.last5WeekMapByWeekKey,
    );
  }
}

class OowFeedItem {
  final String id;
  final String text;
  final String subType;
  final DateTime createdAt;
  final List<String> imageUrls;

  const OowFeedItem({
    required this.id,
    required this.text,
    required this.subType,
    required this.createdAt,
    required this.imageUrls,
  });
}

class OowWeekStat {
  final DateTime weekStart;
  final int doneDays;
  final bool achieved;

  const OowWeekStat({
    required this.weekStart,
    required this.doneDays,
    required this.achieved,
  });
}

class OowWorkoutStat {
  final String name;
  final int count;

  const OowWorkoutStat({
    required this.name,
    required this.count,
  });
}