class ChatListState {
  final bool isLoading;
  final String? errorMessage;

  // pull-to-refresh / 수동 리셋용
  final int refreshTick;

  const ChatListState({
    required this.isLoading,
    required this.errorMessage,
    required this.refreshTick,
  });

  const ChatListState.initial()
      : isLoading = false,
        errorMessage = null,
        refreshTick = 0;

  ChatListState copyWith({
    bool? isLoading,
    String? errorMessage,
    int? refreshTick,
  }) {
    return ChatListState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      refreshTick: refreshTick ?? this.refreshTick,
    );
  }
}
