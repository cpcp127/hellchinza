enum FriendRelation {
  none,       // 신청 가능
  pendingOut, // 내가 신청함(대기중)
  pendingIn,  // 상대가 나에게 신청함(대기중) - 다음 단계에서 수락/거절로 확장
  friends,    // 친구
}

class ProfileState {
  final bool isLoading;
  final bool isBusy;

  final String targetUid;
  final String? myUid;

  final FriendRelation relation;

  const ProfileState({
    required this.isLoading,
    required this.isBusy,
    required this.targetUid,
    required this.myUid,
    required this.relation,
  });

  const ProfileState.initial(this.targetUid)
      : isLoading = true,
        isBusy = false,
        myUid = null,
        relation = FriendRelation.none;

  ProfileState copyWith({
    bool? isLoading,
    bool? isBusy,
    String? myUid,
    FriendRelation? relation,
  }) {
    return ProfileState(
      isLoading: isLoading ?? this.isLoading,
      isBusy: isBusy ?? this.isBusy,
      targetUid: targetUid,
      myUid: myUid ?? this.myUid,
      relation: relation ?? this.relation,
    );
  }

  bool get isMe => myUid != null && myUid == targetUid;

  // 버튼 노출/상태
  bool get showFriendButton => !isMe;
  bool get canSendFriendRequest => !isMe && relation == FriendRelation.none && !isBusy;

  String get friendButtonTitle {
    if (isBusy) return '처리중...';
    switch (relation) {
      case FriendRelation.none:
        return '친구 신청';
      case FriendRelation.pendingOut:
        return '요청 보냄';
      case FriendRelation.pendingIn:
        return '상대가 요청함';
      case FriendRelation.friends:
        return '친구';
    }
  }

  bool get friendButtonEnabled {
    if (isBusy) return false;
    // 지금 단계에서는 "친구 신청"만 가능하게.
    return relation == FriendRelation.none;
  }
}
