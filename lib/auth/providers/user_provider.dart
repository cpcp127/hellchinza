import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'package:hellchinza/auth/data/user_repo.dart';
import 'package:hellchinza/auth/domain/user_mini.dart';
import 'package:hellchinza/auth/domain/user_model.dart';
import 'package:hellchinza/auth/providers/auth_provider.dart';

class UserNotifier extends StateNotifier<UserModel> {
  UserNotifier() : super(UserModel.empty());

  Future<void> updateUserModel(UserModel userModel) async {
    state = userModel;
  }

  Future<void> resetUserModel() async {
    state = UserModel.empty();
  }
}

final myUserModelProvider =
StateNotifierProvider<UserNotifier, UserModel>((ref) {
  return UserNotifier();
});

final userRepoProvider = Provider<UserRepo>((ref) {
  return UserRepo(
    ref.read(firebaseFirestoreProvider),
    ref.read(firebaseAuthProvider),
  );
});

final userMiniProvider =
FutureProvider.family.autoDispose<UserMini?, String>((ref, uid) async {
  final repo = ref.read(userRepoProvider);
  return repo.getUserMini(uid);
});