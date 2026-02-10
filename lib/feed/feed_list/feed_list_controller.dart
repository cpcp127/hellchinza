import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:hellchinza/feed/feed_list/feed_list_state.dart';

final feedListControllerProvider =
    StateNotifierProvider.autoDispose<FeedListController, FeedListState>((ref) {
      return FeedListController(ref);
    });

class FeedListController extends StateNotifier<FeedListState> {
  final Ref ref;

  FeedListController(this.ref) : super(FeedListState());

  Future<void> onChangeMainType(String type) async {
    state = state.copyWith(selectMainType: type);
  }

  Future<void> onChangeSubType(String type) async {
    state = state.copyWith(selectSubType: type);
  }

  Query<Map<String, dynamic>> buildFeedQuery() {
    Query<Map<String, dynamic>> query =
    FirebaseFirestore.instance.collection('feeds');

    // ✅ 메인 타입 필터
    if (state.selectMainType != '전체') {
      query = query.where(
        'mainType',
        isEqualTo: state.selectMainType,
      );
    }

    // ✅ 서브 타입 필터
    if (state.selectMainType != '식단' &&
        state.selectSubType != '전체') {
      query = query.where(
        'subType',
        isEqualTo: state.selectSubType,
      );
    }

    // ✅ 최신순 정렬
    query = query.orderBy(
      'createdAt',
      descending: true,
    );

    return query.where('meetId', isNull: true);
  }

  void refresh() {
    state = state.copyWith(refreshTick: state.refreshTick + 1);
  }
}
