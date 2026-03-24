import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../data/oow_step_repo.dart';
import '../presentation/oow_step_controller.dart';
import '../presentation/oow_step_state.dart';

final oowStepRepoProvider = Provider<OowStepRepo>((ref) {
  return OowStepRepo(
    db: FirebaseFirestore.instance,
  );
});

final oowRefreshTickProvider = StateProvider.family<int, String>(
      (ref, uid) => 0,
);
final oowStepControllerProvider =
StateNotifierProvider.family.autoDispose<OowStepController, OowStepState, String>(
      (ref, uid) {
    final repo = ref.read(oowStepRepoProvider);
    return OowStepController(
      repo: repo,
      uid: uid,
    );
  },
);