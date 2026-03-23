import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'package:hellchinza/auth/data/auth_repo.dart';
import 'package:hellchinza/auth/presentation/auth_controller.dart';
import 'package:hellchinza/auth/presentation/auth_state.dart';
import 'package:hellchinza/auth/presentation/extra_info/extra_info_controller.dart';
import 'package:hellchinza/auth/presentation/extra_info/extra_info_state.dart';

final firebaseAuthProvider = Provider<FirebaseAuth>((ref) {
  return FirebaseAuth.instance;
});

final firebaseFirestoreProvider = Provider<FirebaseFirestore>((ref) {
  return FirebaseFirestore.instance;
});

final authRepoProvider = Provider<AuthRepo>((ref) {
  return AuthRepo(
    ref.read(firebaseAuthProvider),
    ref.read(firebaseFirestoreProvider),
  );
});

final authControllerProvider =
StateNotifierProvider.autoDispose<AuthController, AuthState>((ref) {
  return AuthController(ref);
});

final extraInfoControllerProvider =
StateNotifierProvider.autoDispose<ExtraInfoController, ExtraInfoState>((ref) {
  return ExtraInfoController(ref);
});