class ChatState {
  final bool isLoading;
  final String? errorMessage;

  final String roomId;
  final String? myUid;

  // room 문서 캐시(필드 접근용)
  final Map<String, dynamic>? roomData;

  final Map<String, String> pendingImageLocalPathByMsgId;

  // 입력 가능 여부는 roomData 기반으로 계산
  bool get canSend {
    final r = roomData;
    if (r == null) return false;
    final type = (r['type'] ?? 'dm').toString();
    final allow = (r['allowMessages'] ?? false) == true;
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
  }) {
    return ChatState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      roomId: roomId ?? this.roomId,
      myUid: myUid ?? this.myUid,
      roomData: roomData ?? this.roomData,
      pendingImageLocalPathByMsgId:
      pendingImageLocalPathByMsgId ?? this.pendingImageLocalPathByMsgId,
    );
  }
}
