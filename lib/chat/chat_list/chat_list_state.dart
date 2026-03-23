class ChatListState {
  final bool isLoading;
  final String? errorMessage;
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
      errorMessage: errorMessage ?? this.errorMessage,
      refreshTick: refreshTick ?? this.refreshTick,
    );
  }
}
