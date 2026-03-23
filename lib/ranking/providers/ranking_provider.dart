import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:hellchinza/ranking/data/ranking_repo.dart';
import 'package:hellchinza/ranking/presentation/ranking_controller.dart';
import 'package:hellchinza/ranking/presentation/ranking_state.dart';

final rankingRepoProvider = Provider<RankingRepo>((ref) {
  return RankingRepo();
});

final rankingControllerProvider =
StateNotifierProvider.autoDispose<RankingController, RankingState>((ref) {
  return RankingController(
    ref,

  )..init();
});