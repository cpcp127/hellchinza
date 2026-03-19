import '../../meet/domain/meet_model.dart';

class MeetHeroItem {
  final MeetModel meet;
  final String badge;
  final int score;

  const MeetHeroItem({
    required this.meet,
    required this.badge,
    required this.score,
  });
}

class MeetHomeState {
  final bool isLoading;
  final String? errorMessage;

  final List<MeetHeroItem> heroItems;
  final List<MeetModel> recentActiveMeets;
  final List<MeetModel> popularMeets;
  final List<MeetModel> newestMeets;
  final List<MeetModel> interestMeets;
  final List<MeetModel> lightningHotMeets;

  const MeetHomeState({
    this.isLoading = false,
    this.errorMessage,
    this.heroItems = const [],
    this.recentActiveMeets = const [],
    this.popularMeets = const [],
    this.newestMeets = const [],
    this.interestMeets = const [],
    this.lightningHotMeets = const [],
  });

  MeetHomeState copyWith({
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
    List<MeetHeroItem>? heroItems,
    List<MeetModel>? recentActiveMeets,
    List<MeetModel>? popularMeets,
    List<MeetModel>? newestMeets,
    List<MeetModel>? interestMeets,
    List<MeetModel>? lightningHotMeets,
  }) {
    return MeetHomeState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      heroItems: heroItems ?? this.heroItems,
      recentActiveMeets: recentActiveMeets ?? this.recentActiveMeets,
      popularMeets: popularMeets ?? this.popularMeets,
      newestMeets: newestMeets ?? this.newestMeets,
      interestMeets: interestMeets ?? this.interestMeets,
      lightningHotMeets: lightningHotMeets ?? this.lightningHotMeets,
    );
  }
}