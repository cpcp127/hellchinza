import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:hellchinza/feed/feed_list/feed_list_state.dart';

import '../create_feed/create_feed_state.dart';

final myFriendUidsProvider = StreamProvider<List<String>>((ref) {
  final myUid = FirebaseAuth.instance.currentUser?.uid;
  if (myUid == null) return Stream.value(const []);

  return FirebaseFirestore.instance
      .collection('users')
      .doc(myUid)
      .collection('friends')
      .snapshots()
      .map((snap) {
    return snap.docs
        .map((d) => (d.data()['uid'] ?? d.id).toString())
        .where((e) => e.isNotEmpty)
        .toList();
  });
});
final myBlockedUidsProvider = StreamProvider<List<String>>((ref) {
  final myUid = FirebaseAuth.instance.currentUser?.uid;
  if (myUid == null) return Stream.value(const []);

  return FirebaseFirestore.instance
      .collection('users')
      .doc(myUid)
      .collection('blocks')
      .snapshots()
      .map((snap) {
    return snap.docs
        .map((d) => (d.data()['uid'] ?? d.id).toString())
        .where((e) => e.isNotEmpty)
        .toList();
  });
});

final feedListControllerProvider =
    StateNotifierProvider.autoDispose<FeedListController, FeedListState>((ref) {
      return FeedListController(ref);
    });

class FeedListController extends StateNotifier<FeedListState> {
  final Ref ref;

  FeedListController(this.ref) : super(FeedListState(onlyFriendFeeds: false));

  Future<void> onChangeMainType(String type) async {
    state = state.copyWith(selectMainType: type);
  }

  Future<void> onChangeSubType(String type) async {
    state = state.copyWith(selectSubType: type);
  }

  Query<Map<String, dynamic>> buildFeedQuery() {
    Query<Map<String, dynamic>> query = FirebaseFirestore.instance.collection(
      'feeds',
    );

    if (state.selectMainType != '전체') {
      query = query.where('mainType', isEqualTo: state.selectMainType);
    }

    if (state.selectMainType != '식단' && state.selectSubType != '전체') {
      query = query.where('subType', isEqualTo: state.selectSubType);
    }

    query = query.orderBy('createdAt', descending: true);

    query = query.where('meetId', isNull: true);


    return query;
  }

  void refresh() {
    state = state.copyWith(refreshTick: state.refreshTick + 1);
  }

  void toggleOnlyFriendFeeds(bool on) {
    state = state.copyWith(
      onlyFriendFeeds: on,
      refreshTick: state.refreshTick + 1,
    );
  }

  void applyFilters({
    required String mainType,
    required String subType,
    required bool onlyFriends,
  }) {
    state = state.copyWith(
      selectMainType: mainType,
      selectSubType: subType,
      onlyFriendFeeds: onlyFriends,
      refreshTick: state.refreshTick + 1, // ✅ pagination 강제 새로고침
    );
  }

  bool _isPublicVisibility(Map<String, dynamic> data) {
    final visibility = data['visibility']?.toString();
    return visibility == null ||
        visibility.isEmpty ||
        visibility == FeedVisibility.public;
  }

  bool _isFriendsVisibility(Map<String, dynamic> data) {
    final visibility = data['visibility']?.toString();
    return visibility == FeedVisibility.friends;
  }

  bool canViewFeed({
    required Map<String, dynamic> data,
    required String myUid,
    required Set<String> blockedUidSet,
    required Set<String> friendUidSet,
  }) {
    final authorUid = (data['authorUid'] ?? '').toString();

    if (authorUid.isEmpty) return false;

    // 차단한 유저 글 제외
    if (blockedUidSet.contains(authorUid)) return false;

    final isMine = authorUid == myUid;
    final isFriendAuthor = friendUidSet.contains(authorUid);
    final isPublic = _isPublicVisibility(data);
    final isFriendsOnly = _isFriendsVisibility(data);

    // 친구 피드만 보기
    if (state.onlyFriendFeeds) {
      // 내 글 또는 친구 글만 허용
      if (!isMine && !isFriendAuthor) return false;

      // 내 글/친구 글 중 public, friends 둘 다 보여줌
      if (isPublic) return true;
      if (isFriendsOnly) return true;

      return false;
    }

    // 전체 보기
    if (isMine) return true;
    if (isPublic) return true;
    if (isFriendsOnly && isFriendAuthor) return true;

    return false;
  }
}
