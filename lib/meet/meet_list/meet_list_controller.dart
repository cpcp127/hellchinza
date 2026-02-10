import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../domain/meet_summary_model.dart';
import 'meet_list_state.dart';

final meetListControllerProvider =
StateNotifierProvider<MeetListController, MeetListState>((ref) {
  return MeetListController(ref)..init();
});

class MeetListController extends StateNotifier<MeetListState> {
  MeetListController(this.ref) : super(const MeetListState.initial());
  final Ref ref;

  final _db = FirebaseFirestore.instance;

  static const int pageSize = 12;
  DocumentSnapshot<Map<String, dynamic>>? _lastDoc;

  Query<Map<String, dynamic>> get _baseQuery {
    // 최신 생성 순 (필요하면 dateTime 기준으로 변경 가능)
    return _db.collection('meets').orderBy('createdAt', descending: true);
  }

  Future<void> init() async {
    if (state.items.isNotEmpty) return;
    await fetchFirst();
  }

  Future<void> fetchFirst() async {
    state = state.copyWith(isRefreshing: true, clearError: true);
    _lastDoc = null;

    try {
      final snap = await _baseQuery.limit(pageSize).get();
      final items = snap.docs.map(MeetSummary.fromDoc).toList();

      _lastDoc = snap.docs.isEmpty ? null : snap.docs.last;

      state = state.copyWith(
        isRefreshing: false,
        hasMore: snap.docs.length == pageSize,
        items: items,
      );
    } catch (e) {
      state = state.copyWith(
        isRefreshing: false,
        errorMessage: '모임을 불러오지 못했어요',
      );
    }
  }

  Future<void> fetchMore() async {
    if (state.isLoading || !state.hasMore) return;

    final last = _lastDoc;
    if (last == null) return;

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final snap = await _baseQuery.startAfterDocument(last).limit(pageSize).get();
      final more = snap.docs.map(MeetSummary.fromDoc).toList();

      _lastDoc = snap.docs.isEmpty ? _lastDoc : snap.docs.last;

      state = state.copyWith(
        isLoading: false,
        hasMore: snap.docs.length == pageSize,
        items: [...state.items, ...more],
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: '더 불러오기 실패',
      );
    }
  }

  Query<Map<String, dynamic>> buildQuery() {
    final base = FirebaseFirestore.instance
        .collection('meets')
        .where('status', isEqualTo: 'open')
        .orderBy('createdAt', descending: true);

    if (state.selectSubType == '전체') return base;

    // ✅ category 필터
    return base.where('category', isEqualTo: state.selectSubType);
  }

  Future<void> onChangeSubType(String type) async {
    state = state.copyWith(selectSubType: type);
  }
}
