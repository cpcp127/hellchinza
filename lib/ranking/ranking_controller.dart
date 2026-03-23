import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:hellchinza/ranking/ranking_state.dart';

import '../auth/domain/user_model.dart';
import '../auth/providers/user_provider.dart';

final rankingControllerProvider =
StateNotifierProvider.autoDispose<RankingController, RankingState>((ref) {
  return RankingController(ref)..init();
});

class RankingController extends StateNotifier<RankingState> {
  RankingController(this.ref) : super(const RankingState.initial());

  final Ref ref;

  DocumentSnapshot<Map<String, dynamic>>? _top3LastDoc;

  DocumentSnapshot<Map<String, dynamic>>? get top3LastDoc => _top3LastDoc;



  Query<Map<String, dynamic>> get _baseQuery {
    return FirebaseFirestore.instance
        .collection('users')
        .where('profileCompleted', isEqualTo: true)
        .orderBy('score.weekly', descending: true)
        .orderBy('uid', descending: false);
  }

  Future<void> init() async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final myUser = ref.read(myUserModelProvider);
      final myWeeklyScore = myUser.scoreWeekly;

      final top3Snap = await _baseQuery.limit(3).get();
      _top3LastDoc = top3Snap.docs.isNotEmpty ? top3Snap.docs.last : null;

      final top3 = top3Snap.docs
          .map((e) => UserModel.fromFirestore(e.data()))
          .toList();

      final totalCountSnap = await FirebaseFirestore.instance
          .collection('users')
          .where('profileCompleted', isEqualTo: true)
          .count()
          .get();

      final higherCountSnap = await FirebaseFirestore.instance
          .collection('users')
          .where('profileCompleted', isEqualTo: true)
          .where('score.weekly', isGreaterThan: myWeeklyScore)
          .count()
          .get();

      final total = totalCountSnap.count ?? 0;
      final higher = higherCountSnap.count ?? 0;

      double? topPercent;
      if (total > 0) {
        topPercent = ((higher + 1) / total) * 100;
      }

      state = state.copyWith(
        isLoading: false,
        top3: top3,
        myWeeklyScore: myWeeklyScore,
        higherCount: higher,
        totalRankUsers: total,
        topPercent: topPercent,
      );
    } catch (e) {
      print(e);
      state = state.copyWith(
        isLoading: false,
        errorMessage: '랭킹을 불러오지 못했어요',
      );
    }
  }

  Query<Map<String, dynamic>> buildRestQuery() {
    if (_top3LastDoc == null) {
      return _baseQuery.limit(20);
    }

    return _baseQuery.startAfterDocument(_top3LastDoc!);
  }
}