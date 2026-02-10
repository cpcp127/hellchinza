import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../data/user_mini_repo.dart';
import '../domain/user_mini.dart';

final userMiniRepoProvider = Provider<UserMiniRepo>((ref) {
  return UserMiniRepo(FirebaseFirestore.instance);
});

final userMiniProvider = FutureProvider.family<UserMini?, String>((ref, uid) async {
  final repo = ref.read(userMiniRepoProvider);
  return repo.getUserMini(uid);
});
