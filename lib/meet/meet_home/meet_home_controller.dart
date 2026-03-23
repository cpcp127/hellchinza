import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../data/meet_repo.dart';
import '../domain/meet_model.dart';
import 'meet_home_state.dart';

class MeetHomeController extends StateNotifier<MeetHomeState> {
  MeetHomeController(this._repo) : super(const MeetHomeState());

  final MeetRepo _repo;

  Future<void> init() async {
    if (state.isLoading) return;

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final results = await Future.wait([
        _repo.fetchRecentActiveMeets(),
        _repo.fetchPopularMeets(),
        _repo.fetchNewestMeets(),
        _repo.fetchInterestMeets(),
        _repo.fetchLightningHotMeets(),
      ]);

      final recentActive = results[0] as List<MeetModel>;
      final popular = results[1] as List<MeetModel>;
      final newest = results[2] as List<MeetModel>;
      final interest = results[3] as List<MeetModel>;
      final lightning = results[4] as List<MeetModel>;

      final hero = _buildHeroItems(
        recentActive: recentActive,
        popular: popular,
        newest: newest,
        interest: interest,
        lightning: lightning,
      );

      state = state.copyWith(
        isLoading: false,
        heroItems: hero,
        recentActiveMeets: recentActive,
        popularMeets: popular,
        newestMeets: newest,
        interestMeets: interest,
        lightningHotMeets: lightning,
      );
    } catch (e) {
      debugPrint('MeetHome init error: $e');

      state = state.copyWith(isLoading: false, errorMessage: '모임 홈을 불러오지 못했어요');
    }
  }

  Future<void> refresh() async {
    state = const MeetHomeState();
    await init();
  }

  List<MeetHeroItem> _buildHeroItems({
    required List<MeetModel> recentActive,
    required List<MeetModel> popular,
    required List<MeetModel> newest,
    required List<MeetModel> interest,
    required List<MeetModel> lightning,
  }) {
    final map = <String, MeetHeroItem>{};

    void addItems(List<MeetModel> items, String badge, int baseScore) {
      for (int i = 0; i < items.length; i++) {
        final meet = items[i];
        final score = baseScore - i;

        if (!map.containsKey(meet.id)) {
          map[meet.id] = MeetHeroItem(meet: meet, badge: badge, score: score);
        } else {
          final old = map[meet.id]!;
          if (score > old.score) {
            map[meet.id] = MeetHeroItem(meet: meet, badge: badge, score: score);
          }
        }
      }
    }

    addItems(recentActive, '방금 활동', 100);
    addItems(popular, '인기 모임', 90);
    addItems(interest, '관심사 추천', 80);
    addItems(lightning, '번개 활발', 70);
    addItems(newest, '새로 생김', 60);

    final result = map.values.toList()
      ..sort((a, b) => b.score.compareTo(a.score));

    return result.take(8).toList();
  }
}
