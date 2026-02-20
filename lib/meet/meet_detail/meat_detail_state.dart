import 'package:flutter/foundation.dart';

import '../domain/meet_model.dart';

class MeetDetailState {
  final bool isLoading;
  final String? errorMessage;

  final MeetModel? meet;
  final String? myRequestStatus;
  final String? myUid;

  const MeetDetailState({
    required this.isLoading,
    required this.errorMessage,
    required this.meet,
    required this.myUid,
    this.myRequestStatus,
  });

  const MeetDetailState.initial()
      : isLoading = true,
        errorMessage = null,
        meet = null,
        myUid = null,
        myRequestStatus = null;

  // ✅ copyWith
  MeetDetailState copyWith({
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,

    MeetModel? meet,
    bool clearMeet = false,

    String? myUid,

    String? myRequestStatus,
    bool clearMyRequestStatus = false,
  }) {
    return MeetDetailState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),

      meet: clearMeet ? null : (meet ?? this.meet),
      myUid: myUid ?? this.myUid,

      myRequestStatus: clearMyRequestStatus
          ? null
          : (myRequestStatus ?? this.myRequestStatus),
    );
  }

  // ---------------- getters ----------------

  bool get hasMeet => meet != null;

  bool get isOwner =>
      meet != null && myUid != null && meet!.authorUid == myUid;

  bool get isRequested => myRequestStatus == 'pending';

  bool get isMember {
    if (meet == null || myUid == null) return false;
    return meet!.userUids.contains(myUid);
  }

  bool get isFull {
    if (meet == null) return false;
    return meet!.currentMemberCount >= meet!.maxMembers;
  }

  bool get canRequest =>
      meet != null &&
          myUid != null &&
          !isOwner &&
          !isMember &&
          meet!.needApproval == true &&
          meet!.status == 'open' &&
          !isFull;
}
