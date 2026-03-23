import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:hellchinza/auth/domain/user_model.dart';
import 'package:hellchinza/auth/providers/user_provider.dart';
import 'package:hellchinza/home/data/home_repo.dart';
import 'package:hellchinza/home/presentation/home_controller.dart';
import 'package:hellchinza/services/push_token_service.dart';

import '../presentation/home_state.dart';

final homeFirebaseAuthProvider = Provider<fb_auth.FirebaseAuth>((ref) {
  return fb_auth.FirebaseAuth.instance;
});

final homeFirestoreProvider = Provider<FirebaseFirestore>((ref) {
  return FirebaseFirestore.instance;
});

final homeRepoProvider = Provider<HomeRepo>((ref) {
  return HomeRepo(
    ref.read(homeFirestoreProvider),
    ref.read(homeFirebaseAuthProvider),
  );
});

final homeControllerProvider =
    StateNotifierProvider.autoDispose<HomeController, HomeState>((ref) {
      return HomeController(ref);
    });

final homeCurrentUidProvider = Provider<String?>((ref) {
  return ref.read(homeRepoProvider).currentUid;
});

final homeInitProvider = FutureProvider.autoDispose<bool>((ref) async {
  final repo = ref.read(homeRepoProvider);
  final uid = repo.currentUid;
  if (uid == null || uid.isEmpty) return false;

  final UserModel? userModel = await repo.fetchUser(uid);
  if (userModel != null) {
    await ref.read(myUserModelProvider.notifier).updateUserModel(userModel);
  }

  await PushTokenService.instance.init();
  return true;
});

final hasUnreadNotificationProvider = StreamProvider.autoDispose<bool>((ref) {
  return ref.read(homeRepoProvider).hasUnreadNotificationStream();
});
