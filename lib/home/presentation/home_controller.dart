import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:hellchinza/common/common_action_sheet.dart';

import 'home_state.dart';

class HomeController extends StateNotifier<HomeState> {
  HomeController(this.ref) : super(HomeState());

  final Ref ref;

  static const List<String> pageTitles = ['오운완', '피드', '모임', '프로필'];

  void onTapBottomNav(int index) {
    if (index == 2) return;

    final nextPageIndex = index > 2 ? index - 1 : index;

    state = state.copyWith(navIndex: index, pageIndex: nextPageIndex);
  }

  Future<void> showCreateActionSheet({
    required BuildContext context,
    required VoidCallback onCreateFeed,
    required VoidCallback onCreateMeeting,
  }) async {
    final items = <CommonActionSheetItem>[
      CommonActionSheetItem(
        icon: Icons.edit_note,
        title: '피드 작성하기',
        onTap: onCreateFeed,
      ),
      CommonActionSheetItem(
        icon: Icons.groups_outlined,
        title: '모임 만들기',
        onTap: onCreateMeeting,
      ),
    ];

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => CommonActionSheet(title: '작성', items: items),
    );
  }
}
