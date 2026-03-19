import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../meet/domain/meet_model.dart';
import 'meet_home_repo.dart';
import 'meet_home_state.dart';

final meetHomeRepoProvider = Provider<MeetHomeRepo>((ref) {
  return MeetHomeRepo(FirebaseFirestore.instance);
});

final meetHomeControllerProvider =
StateNotifierProvider.autoDispose<MeetHomeController, MeetHomeState>((ref) {
  return MeetHomeController(ref);
});

class MeetHomeController extends StateNotifier<MeetHomeState> {
  MeetHomeController(this.ref) : super(const MeetHomeState());

  final Ref ref;

  Future<void> init() async {
    if (state.isLoading) return;

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final repo = ref.read(meetHomeRepoProvider);

      final results = await Future.wait([
        repo.fetchRecentActiveMeets(),
        repo.fetchPopularMeets(),
        repo.fetchNewestMeets(),
        repo.fetchInterestMeets(),
        repo.fetchLightningHotMeets(),
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

      state = state.copyWith(
        isLoading: false,
        errorMessage: '모임 홈을 불러오지 못했어요',
      );
    }
  }

  Future<void> refresh() async {
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
          map[meet.id] = MeetHeroItem(
            meet: meet,
            badge: badge,
            score: score,
          );
        } else {
          final old = map[meet.id]!;
          if (score > old.score) {
            map[meet.id] = MeetHeroItem(
              meet: meet,
              badge: badge,
              score: score,
            );
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