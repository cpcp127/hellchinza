import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/app_text_style.dart';
import '../services/snackbar_service.dart';

class BlockUserListView extends StatefulWidget {
  const BlockUserListView({super.key});

  @override
  State<BlockUserListView> createState() => _BlockUserListViewState();
}

class _BlockUserListViewState extends State<BlockUserListView> {
  final uid = FirebaseAuth.instance.currentUser?.uid;

  Future<void> _unblock(String blockedUid) async {
    if (uid == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('blocks')
          .doc(blockedUid)
          .delete();

      SnackbarService.show(
        type: AppSnackType.success,
        message: '차단을 해제했어요',
      );
    } catch (e) {
      SnackbarService.show(
        type: AppSnackType.error,
        message: '차단 해제에 실패했어요',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (uid == null) {
      return const Scaffold(
        body: Center(child: Text('로그인이 필요해요')),
      );
    }

    final query = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('blocks')
        .orderBy('createdAt', descending: true);

    return Scaffold(
      appBar: AppBar(
        title: const Text('차단 사용자 관리'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: query.snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snap.data?.docs ?? [];

          if (docs.isEmpty) {
            return Center(
              child: Text(
                '차단한 사용자가 없어요',
                style: AppTextStyle.bodyMediumStyle.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final data = docs[index].data();
              final blockedUid = (data['uid'] ?? docs[index].id).toString();

              return _BlockedUserTile(
                blockedUid: blockedUid,
                onTapUnblock: () => _unblock(blockedUid),
              );
            },
          );
        },
      ),
    );
  }
}

class _BlockedUserTile extends StatelessWidget {
  const _BlockedUserTile({
    required this.blockedUid,
    required this.onTapUnblock,
  });

  final String blockedUid;
  final VoidCallback onTapUnblock;

  @override
  Widget build(BuildContext context) {
    final userRef = FirebaseFirestore.instance
        .collection('users')
        .doc(blockedUid);

    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: userRef.get(),
      builder: (context, snap) {
        final data = snap.data?.data();
        final nickname = data?['nickname']?.toString() ?? '알 수 없는 사용자';
        final photoUrl = data?['photoUrl']?.toString();

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.bgWhite,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.borderSecondary),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: AppColors.bgSecondary,
                backgroundImage: (photoUrl != null && photoUrl.isNotEmpty)
                    ? NetworkImage(photoUrl)
                    : null,
                child: (photoUrl == null || photoUrl.isEmpty)
                    ? Icon(
                  Icons.person,
                  color: AppColors.icSecondary,
                )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  nickname,
                  style: AppTextStyle.titleSmallBoldStyle.copyWith(
                    color: AppColors.textDefault,
                  ),
                ),
              ),
              TextButton(
                onPressed: onTapUnblock,
                child: Text(
                  '차단 해제',
                  style: AppTextStyle.labelMediumStyle.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}