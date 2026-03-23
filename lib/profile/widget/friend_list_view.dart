import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_pagination/firebase_pagination.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/user_provider.dart';
import '../../common/common_profile_avatar.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_text_style.dart';
import '../profile_view.dart';

class FriendListView extends ConsumerWidget {
  const FriendListView({
    super.key,
    required this.targetUid,
  });

  final String targetUid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = FirebaseFirestore.instance
        .collection('users')
        .doc(targetUid)
        .collection('friends')
        .orderBy('createdAt', descending: true);

    return Scaffold(
      appBar: AppBar(
        title: Text('친구', style: AppTextStyle.titleMediumBoldStyle),
      ),
      body: FirestorePagination(
        query: query,
        limit: 15,
        isLive: false,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        onEmpty: Center(
          child: Text(
            '아직 친구가 없어요',
            style: AppTextStyle.bodyMediumStyle.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
        itemBuilder: (context, docs, index) {
          final doc = docs[index];
          final data = (doc.data() as Map?)?.cast<String, dynamic>() ?? {};
          final friendUid = (data['friendUid'] ?? doc.id).toString();

          final asyncMini = ref.watch(userMiniProvider(friendUid));

          return asyncMini.when(
            loading: () => const Padding(
              padding: EdgeInsets.only(bottom: 10),
              child: CupertinoActivityIndicator(),
            ),
            error: (e, _) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                '친구 불러오기 실패 $e',
                style: AppTextStyle.bodySmallStyle.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            data: (mini) {
              if (mini == null) return const SizedBox.shrink();

              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => ProfileView(uid: mini.uid)),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.bgWhite,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.borderSecondary),
                    ),
                    child: Row(
                      children: [
                        CommonProfileAvatar(
                          imageUrl: mini.photoUrl,
                          size: 44,
                          uid: friendUid,
                          gender: mini.gender,lastWeeklyRank: mini.lastWeeklyRank,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            mini.nickname,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyle.titleSmallBoldStyle.copyWith(
                              color: AppColors.textDefault,
                            ),
                          ),
                        ),
                        const Icon(Icons.chevron_right, color: AppColors.icSecondary),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}