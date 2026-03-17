import '../auth/domain/user_model.dart';

class RankingState {
  final bool isLoading;
  final String? errorMessage;
  final List<UserModel> top3;

  final int myWeeklyScore;
  final int higherCount;
  final int totalRankUsers;
  final double? topPercent;

  const RankingState({
    required this.isLoading,
    required this.errorMessage,
    required this.top3,
    required this.myWeeklyScore,
    required this.higherCount,
    required this.totalRankUsers,
    required this.topPercent,
  });

  const RankingState.initial()
      : isLoading = true,
        errorMessage = null,
        top3 = const [],
        myWeeklyScore = 0,
        higherCount = 0,
        totalRankUsers = 0,
        topPercent = null;

  RankingState copyWith({
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
    List<UserModel>? top3,
    int? myWeeklyScore,
    int? higherCount,
    int? totalRankUsers,
    double? topPercent,
  }) {
    return RankingState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      top3: top3 ?? this.top3,
      myWeeklyScore: myWeeklyScore ?? this.myWeeklyScore,
      higherCount: higherCount ?? this.higherCount,
      totalRankUsers: totalRankUsers ?? this.totalRankUsers,
      topPercent: topPercent ?? this.topPercent,
    );
  }
}