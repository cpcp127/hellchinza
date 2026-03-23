import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../data/meet_repo.dart';
import 'meet_list_state.dart';

class MeetListController extends StateNotifier<MeetListState> {
  MeetListController(this._repo) : super(const MeetListState.initial());

  final MeetRepo _repo;

  static const int pageSize = 12;

  Query<Map<String, dynamic>> buildQuery() {
    return _repo.buildMeetListQuery(
      selectSubType: state.selectSubType,
      searchText: state.searchText,
    );
  }

  Future<void> onChangeSubType(String type) async {
    state = state.copyWith(
      selectSubType: type,
      refreshTick: state.refreshTick + 1,
    );
  }

  void refresh() {
    state = state.copyWith(
      refreshTick: state.refreshTick + 1,
    );
  }

  void setSearchText(String v) {
    state = state.copyWith(
      searchText: v,
      refreshTick: state.refreshTick + 1,
    );
  }
}