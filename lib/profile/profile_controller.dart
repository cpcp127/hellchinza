import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:hellchinza/profile/data/profile_repo.dart';
import 'package:hellchinza/profile/profile_state.dart';

class ProfileController extends StateNotifier<ProfileState> {
  ProfileController(this.ref, this._repo, this.targetUid)
    : super(ProfileState.initial(targetUid));

  final Ref ref;
  final ProfileRepo _repo;
  final String targetUid;

  Future<void> init() async {
    final myUid = _repo.currentUid;

    if (myUid == null) {
      state = state.copyWith(
        isLoading: false,
        myUid: null,
        relation: FriendRelation.none,
      );
      return;
    }

    try {
      final relation = await _repo.fetchRelation(targetUid);

      state = state.copyWith(
        isLoading: false,
        myUid: myUid,
        relation: relation,
      );
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        myUid: myUid,
        relation: FriendRelation.none,
      );
    }
  }

  Future<String> sendFriendRequest({
    required String otherUid,
    required String requestText,
  }) async {
    state = state.copyWith(isBusy: true);

    try {
      final roomId = await _repo.sendFriendRequest(
        otherUid: otherUid,
        requestText: requestText,
      );

      state = state.copyWith(
        isBusy: false,
        relation: FriendRelation.pendingOut,
      );
      return roomId;
    } catch (e) {
      state = state.copyWith(isBusy: false);
      rethrow;
    }
  }

  Future<void> blockUser({required String targetUid}) async {
    state = state.copyWith(isBusy: true);

    try {
      await _repo.blockUser(targetUid: targetUid);
      state = state.copyWith(isBusy: false);
    } catch (_) {
      state = state.copyWith(isBusy: false);
      rethrow;
    }
  }
}
