import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../data/claim_repo.dart';
import '../domain/claim_model.dart';
import '../presentation/claim_controller.dart';
import '../presentation/claim_state.dart';

final firebaseFirestoreProvider = Provider<FirebaseFirestore>((ref) {
  return FirebaseFirestore.instance;
});

final claimRepoProvider = Provider<ClaimRepo>((ref) {
  return ClaimRepo(ref.read(firebaseFirestoreProvider));
});

final claimControllerProvider = StateNotifierProvider.autoDispose
    .family<ClaimController, ClaimState, ClaimTarget>((ref, target) {
      return ClaimController(ref, target);
    });
