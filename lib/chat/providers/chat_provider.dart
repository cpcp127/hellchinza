import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../auth/domain/user_mini.dart';
import '../../chat/data/chat_repo.dart';

import '../chat_list/chat_list_controller.dart';
import '../chat_list/chat_list_state.dart';
import '../chat_room/chat_room_controller.dart';
import '../chat_room/chat_room_state.dart';

final chatFirebaseAuthProvider = Provider<fb_auth.FirebaseAuth>((ref) {
  return fb_auth.FirebaseAuth.instance;
});

final chatFirestoreProvider = Provider<FirebaseFirestore>((ref) {
  return FirebaseFirestore.instance;
});

final chatStorageProvider = Provider<FirebaseStorage>((ref) {
  return FirebaseStorage.instance;
});

final chatRepoProvider = Provider<ChatRepo>((ref) {
  return ChatRepo(
    ref.read(chatFirestoreProvider),
    ref.read(chatFirebaseAuthProvider),
    ref.read(chatStorageProvider),
  );
});

final chatListControllerProvider =
StateNotifierProvider.autoDispose<ChatListController, ChatListState>((ref) {
  return ChatListController(ref);
});

final chatControllerProvider = StateNotifierProvider.family
    .autoDispose<ChatController, ChatState, String>((ref, roomId) {
  final controller = ChatController(ref: ref, roomId: roomId);
  controller.init();
  return controller;
});

final unreadChatCountProvider = StreamProvider<int>((ref) {
  return ref.read(chatRepoProvider).unreadChatCountStream();
});

final chatRoomProvider =
StreamProvider.family<DocumentSnapshot<Map<String, dynamic>>, String>((
    ref,
    roomId,
    ) {
  return ref.read(chatRepoProvider).watchRoom(roomId);
});

final chatRoomUsersMapProvider =
FutureProvider.family.autoDispose<Map<String, UserMini>, String>((
    ref,
    roomId,
    ) async {
  return ref.read(chatRepoProvider).fetchRoomUsersMap(roomId);
});

final otherUidProvider = Provider.family<String?, String>((ref, roomId) {
  final roomAsync = ref.watch(chatRoomProvider(roomId));
  final myUid = ref.read(chatRepoProvider).currentUid;

  return roomAsync.when(
    data: (doc) {
      final data = doc.data();
      if (data == null || myUid == null) return null;

      final type = (data['type'] ?? 'dm').toString();
      if (type != 'dm') return null;

      final members = List<String>.from(data['userUids'] ?? const []);
      final other = members.where((u) => u != myUid).toList();
      return other.isEmpty ? null : other.first;
    },
    loading: () => null,
    error: (_, __) => null,
  );
});