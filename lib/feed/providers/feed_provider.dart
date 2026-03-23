import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../create_feed/create_feed_controller.dart';
import '../create_feed/create_feed_state.dart';
import '../data/feed_repo.dart';
import '../domain/feed_model.dart';
import '../feed_list/feed_list_controller.dart';
import '../feed_list/feed_list_state.dart';

final feedFirebaseAuthProvider = Provider<fb_auth.FirebaseAuth>((ref) {
  return fb_auth.FirebaseAuth.instance;
});

final feedFirestoreProvider = Provider<FirebaseFirestore>((ref) {
  return FirebaseFirestore.instance;
});

final feedStorageProvider = Provider<FirebaseStorage>((ref) {
  return FirebaseStorage.instance;
});

final feedRepoProvider = Provider<FeedRepo>((ref) {
  return FeedRepo(
    ref.read(feedFirestoreProvider),
    ref.read(feedFirebaseAuthProvider),
    ref.read(feedStorageProvider),
  );
});

final createFeedControllerProvider =
StateNotifierProvider.autoDispose<CreateFeedController, CreateFeedState>((ref) {
  return CreateFeedController(ref);
});

final feedListControllerProvider =
StateNotifierProvider.autoDispose<FeedListController, FeedListState>((ref) {
  return FeedListController(ref);
});

final myFriendUidsProvider = StreamProvider<List<String>>((ref) {
  return ref.read(feedRepoProvider).watchMyFriendUids();
});

final myBlockedUidsProvider = StreamProvider<List<String>>((ref) {
  return ref.read(feedRepoProvider).watchMyBlockedUids();
});

final feedDocProvider = FutureProvider.family<FeedModel?, String>((ref, feedId) async {
  return ref.read(feedRepoProvider).getFeed(feedId);
});