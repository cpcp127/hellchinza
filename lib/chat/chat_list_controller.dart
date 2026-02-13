import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'chat_list_state.dart';
import 'chat_list_view.dart';

final chatListControllerProvider =
StateNotifierProvider.autoDispose<ChatListController, ChatListState>((ref) {
  return ChatListController(ref);
});

class ChatListController extends StateNotifier<ChatListState> {
  ChatListController(this.ref) : super(const ChatListState.initial());

  final Ref ref;

  void refresh() {
    state = state.copyWith(refreshTick: state.refreshTick + 1);
  }

  Query<Map<String, dynamic>> buildQuery() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      // 로그인 안됐을 때도 빌드가 깨지지 않게 "빈 쿼리" 비슷하게 처리
      return FirebaseFirestore.instance
          .collection('chatRooms')
          .where('userUids', arrayContains: '__none__')
          .orderBy('lastMessageAt', descending: true);
    }

    // ✅ 내 채팅방만
    return FirebaseFirestore.instance
        .collection('chatRooms')
        .where('userUids', arrayContains: uid)
        .orderBy('lastMessageAt', descending: true);
  }
}
