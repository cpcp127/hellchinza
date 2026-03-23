class ChatState {
  final bool isLoading;
  final String? errorMessage;
  final String roomId;
  final String? myUid;
  final Map<String, dynamic>? roomData;
  final Map<String, String> pendingImageLocalPathByMsgId;

  bool get canSend {
    final room = roomData;
    if (room == null) return false;

    final type = (room['type'] ?? 'dm').toString();
    final allow = (room['allowMessages'] ?? false) == true;
    return type == 'group' || allow;
  }

  const ChatState({
    required this.isLoading,
    required this.errorMessage,
    required this.roomId,
    required this.myUid,
    required this.roomData,
    required this.pendingImageLocalPathByMsgId,
  });

  const ChatState.initial({required this.roomId})
      : isLoading = true,
        errorMessage = null,
        myUid = null,
        roomData = null,
        pendingImageLocalPathByMsgId = const {};

  ChatState copyWith({
    bool? isLoading,
    String? errorMessage,
    String? roomId,
    String? myUid,
    Map<String, dynamic>? roomData,
    Map<String, String>? pendingImageLocalPathByMsgId,
    bool clearError = false,
  }) {
    return ChatState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      roomId: roomId ?? this.roomId,
      myUid: myUid ?? this.myUid,
      roomData: roomData ?? this.roomData,
      pendingImageLocalPathByMsgId:
      pendingImageLocalPathByMsgId ?? this.pendingImageLocalPathByMsgId,
    );
  }
}