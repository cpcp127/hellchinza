import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:hellchinza/home/home_state.dart';

import '../auth/domain/user_model.dart';
import '../common/common_action_sheet.dart';

final homeControllerProvider =
    StateNotifierProvider.autoDispose<HomeController, HomeState>((ref) {
      return HomeController(ref);
    });


final homeInitProvider = FutureProvider.autoDispose<bool>((ref) async {
  UserModel? userModel = await ref
      .read(homeControllerProvider.notifier)
      .fetchUser(FirebaseAuth.instance.currentUser!.uid);
  ref.read(myUserModelProvider.notifier).updateUserModel(userModel!);
  return true;
});

class HomeController extends StateNotifier<HomeState> {
  final Ref ref;

  HomeController(this.ref) : super(HomeState());

  Future<UserModel?> fetchUser(String uid) async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
    if (!doc.exists) return null;
    final data = doc.data();
    if (data == null) return null;
    return UserModel.fromFirestore(data);
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
      builder: (_) => CommonActionSheet(
        title: '작성',
        items: items,
      ),
    );
  }

}
