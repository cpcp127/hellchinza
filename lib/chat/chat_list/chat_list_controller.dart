import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'chat_list_state.dart';

class ChatListController extends StateNotifier<ChatListState> {
  ChatListController(this.ref) : super(const ChatListState.initial());

  final Ref ref;

  void refresh() {
    state = state.copyWith(refreshTick: state.refreshTick + 1);
  }

  void clearError() {
    state = state.copyWith(errorMessage: null);
  }
}