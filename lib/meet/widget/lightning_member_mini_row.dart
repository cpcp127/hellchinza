import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:hellchinza/common/common_profile_avatar.dart';

import '../../common/common_network_image.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_text_style.dart';

class LightningMemberMiniRow extends StatelessWidget {
  const LightningMemberMiniRow({required this.memberUids});

  final List<String> memberUids;

  @override
  Widget build(BuildContext context) {
    final uids = memberUids.take(3).toList();
    if (uids.isEmpty) return const SizedBox.shrink();

    final q = FirebaseFirestore.instance
        .collection('users')
        .where('uid', whereIn: uids);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: q.snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return Row(
            children: List.generate(uids.length, (_) => _CircleSkeleton()),
          );
        }

        // whereIn은 순서 보장 X → uid 기준으로 다시 정렬
        final map = <String, Map<String, dynamic>>{};
        for (final d in snap.data!.docs) {
          final data = d.data();
          final uid = (data['uid'] ?? d.id).toString();
          map[uid] = data;
        }

        final users = uids
            .map((uid) => map[uid])
            .whereType<Map<String, dynamic>>()
            .toList();

        return Row(
          children: [
            ...users.map((u) {
              final photoUrl = u['photoUrl']?.toString();
              final nick = u['nickname']?.toString() ?? '';
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Row(
                  children: [
                    CommonProfileAvatar(imageUrl: photoUrl, size: 22),
                    const SizedBox(width: 6),
                    Text(
                      nick,
                      style: AppTextStyle.labelSmallStyle.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              );
            }),
            if (memberUids.length > 3)
              Text(
                '+${memberUids.length - 3}',
                style: AppTextStyle.labelSmallStyle.copyWith(
                  color: AppColors.textTeritary,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _CircleSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Container(
        width: 22,
        height: 22,
        decoration: const BoxDecoration(
          color: AppColors.gray100,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
