import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:hellchinza/auth/domain/user_model.dart';
import 'package:hellchinza/meet/domain/meet_model.dart';
import 'package:hellchinza/profile/data/profile_repo.dart';

import '../profile_controller.dart';
import '../profile_state.dart';


final profileRepoProvider = Provider<ProfileRepo>((ref) {
  return ProfileRepo();
});

final profileControllerProvider = StateNotifierProvider.autoDispose
    .family<ProfileController, ProfileState, String>((ref, uid) {
  return ProfileController(
    ref,
    ref.read(profileRepoProvider),
    uid,
  )..init();
});

final isFriendProvider = FutureProvider.family<bool, String>((ref, targetUid) async {
  return ref.read(profileRepoProvider).isFriend(targetUid);
});

final hostedMeetPreviewProvider =
FutureProvider.autoDispose.family<List<MeetModel>, String>((ref, uid) async {
  return ref.read(profileRepoProvider).fetchHostedMeetPreview(uid);
});

final hostedMeetAllProvider =
FutureProvider.autoDispose.family<List<MeetModel>, String>((ref, uid) async {
  return ref.read(profileRepoProvider).fetchHostedMeetAll(uid);
});

final joinedMeetPreviewProvider =
FutureProvider.autoDispose.family<List<MeetModel>, String>((ref, uid) async {
  return ref.read(profileRepoProvider).fetchJoinedMeetPreview(uid);
});

final joinedMeetAllProvider =
FutureProvider.autoDispose.family<List<MeetModel>, String>((ref, uid) async {
  return ref.read(profileRepoProvider).fetchJoinedMeetAll(uid);
});

final userByUidProvider = FutureProvider.family<UserModel?, String>((ref, uid) async {
  return ref.read(profileRepoProvider).fetchUserByUid(uid);
});

final friendCountProvider = FutureProvider.family<int, String>((ref, uid) async {
  return ref.read(profileRepoProvider).fetchFriendCount(uid);
});