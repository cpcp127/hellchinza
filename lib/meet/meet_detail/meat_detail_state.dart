import '../domain/meet_model.dart';

class MeetDetailState {
  final bool isLoading;
  final String? errorMessage;

  final MeetModel? meet;
  final String? myRequestStatus;
  final String? myUid;

  final bool isMember;
  final int memberCount;

  const MeetDetailState({
    required this.isLoading,
    required this.errorMessage,
    required this.meet,
    required this.myUid,
    required this.isMember,
    required this.memberCount,
    this.myRequestStatus,
  });

  const MeetDetailState.initial()
      : isLoading = true,
        errorMessage = null,
        meet = null,
        myUid = null,
        myRequestStatus = null,
        isMember = false,
        memberCount = 0;

  MeetDetailState copyWith({
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
    MeetModel? meet,
    bool clearMeet = false,
    String? myUid,
    String? myRequestStatus,
    bool clearMyRequestStatus = false,
    bool? isMember,
    int? memberCount,
  }) {
    return MeetDetailState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      meet: clearMeet ? null : (meet ?? this.meet),
      myUid: myUid ?? this.myUid,
      myRequestStatus: clearMyRequestStatus
          ? null
          : (myRequestStatus ?? this.myRequestStatus),
      isMember: isMember ?? this.isMember,
      memberCount: memberCount ?? this.memberCount,
    );
  }

  bool get hasMeet => meet != null;

  bool get isOwner =>
      meet != null && myUid != null && meet!.authorUid == myUid;

  bool get isRequested => myRequestStatus == 'pending';

  bool get isFull {
    if (meet == null) return false;
    return memberCount >= meet!.maxMembers;
  }

  bool get canRequest =>
      meet != null &&
          myUid != null &&
          !isOwner &&
          !isMember &&
          meet!.needApproval &&
          meet!.status == 'open' &&
          !isFull;
}