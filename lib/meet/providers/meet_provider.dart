import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../data/meet_repo.dart';
import '../domain/lightning_model.dart';
import '../domain/meet_summary_model.dart';
import '../lightning_create/lightning_create_controller.dart';
import '../lightning_create/lightning_create_state.dart';
import '../meet_create/meet_create_controller.dart';
import '../meet_create/meet_create_state.dart';
import '../meet_detail/meat_detail_controller.dart';
import '../meet_detail/meat_detail_state.dart';
import '../meet_home/meet_home_controller.dart';
import '../meet_home/meet_home_state.dart';
import '../meet_list/meet_list_controller.dart';
import '../meet_list/meet_list_state.dart';


final meetRepoProvider = Provider<MeetRepo>((ref) {
  return MeetRepo();
});

final meetSummaryProvider = FutureProvider.family<MeetSummary?, String>((
    ref,
    meetId,
    ) async {
  final repo = ref.read(meetRepoProvider);
  return repo.fetchMeetSummary(meetId);
});

final meetMemberCountProvider = FutureProvider.family<int, String>((
    ref,
    meetId,
    ) async {
  final repo = ref.read(meetRepoProvider);
  return repo.fetchMeetMemberCount(meetId);
});

final meetLightningSectionProvider =
FutureProvider.family<List<LightningModel>, String>((ref, meetId) async {
  final repo = ref.read(meetRepoProvider);
  return repo.fetchOpenLightnings(meetId, limit: 5);
});

final meetPhotoFeedSectionProvider =
FutureProvider.family<List<Map<String, dynamic>>, String>((ref, meetId) async {
  final repo = ref.read(meetRepoProvider);
  return repo.fetchMeetPhotoFeeds(meetId, limit: 9);
});

final meetHomeControllerProvider =
StateNotifierProvider.autoDispose<MeetHomeController, MeetHomeState>((ref) {
  return MeetHomeController(ref.read(meetRepoProvider));
});

final meetListControllerProvider =
StateNotifierProvider.autoDispose<MeetListController, MeetListState>((ref) {
  return MeetListController(ref.read(meetRepoProvider));
});

final meetCreateControllerProvider =
StateNotifierProvider.autoDispose<MeetCreateController, MeetCreateState>(
      (ref) {
    return MeetCreateController(
      ref,
      ref.read(meetRepoProvider),
    );
  },
);

final lightningCreateControllerProvider = StateNotifierProvider.autoDispose
    .family<LightningCreateController, LightningCreateState, String>((
    ref,
    meetId,
    ) {
  return LightningCreateController(
    ref,
    ref.read(meetRepoProvider),
    meetId,
  );
});

final meetDetailControllerProvider = StateNotifierProvider.autoDispose
    .family<MeetDetailController, MeetDetailState, String>((ref, meetId) {
  return MeetDetailController(
    ref,
    ref.read(meetRepoProvider),
    meetId,
  )..init();
});

final meetRequestUidsProvider = FutureProvider.autoDispose
    .family<List<String>, String>((ref, meetId) async {
  final snap = await FirebaseFirestore.instance
      .collection('meets')
      .doc(meetId)
      .collection('requests')
      .where('status', isEqualTo: 'pending')
      .get();

  return snap.docs.map((d) => d.id).toList();
});

final meetMembersProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, meetId) async {
  final snap = await FirebaseFirestore.instance
      .collection('meets')
      .doc(meetId)
      .collection('members')
      .orderBy('joinedAt', descending: false)
      .get();

  return snap.docs.map((d) {
    final data = d.data();
    return {
      'uid': (data['uid'] ?? d.id).toString(),
      'role': (data['role'] ?? 'member').toString(),
      'joinedAt': data['joinedAt'],
    };
  }).toList();
});
