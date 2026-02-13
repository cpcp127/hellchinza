import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/domain/user_mini_provider.dart';
import '../auth/presentation/auth_controller.dart';
import '../constants/app_colors.dart';
import '../constants/app_text_style.dart';
import 'common_profile_avatar.dart';

class LikeUserBottomSheet {
  static Future<void> show({
    required BuildContext context,
    required List<String> likeUids,
  }) async {
    if (likeUids.isEmpty) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _LikeUserSheetContent(likeUids: likeUids),
    );
  }
}
class _LikeUserSheetContent extends StatelessWidget {
  final List<String> likeUids;

  const _LikeUserSheetContent({
    required this.likeUids,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.6,
      ),
      decoration: const BoxDecoration(
        color: AppColors.bgWhite,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 8),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.gray300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '좋아요',
            style: AppTextStyle.titleMediumBoldStyle,
          ),
          const SizedBox(height: 12),


          Expanded(
            child: ListView.builder(
              itemCount: likeUids.length,
              itemBuilder: (context, index) {
                return _LikeUserItem(uid: likeUids[index]);
              },
            ),
          ),
        ],
      ),
    );
  }
}
class _LikeUserItem extends ConsumerWidget {
  final String uid;

  const _LikeUserItem({
    required this.uid,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncMini = ref.watch(userMiniProvider(uid));
    return asyncMini.when(
      loading: () => Center(child: CupertinoActivityIndicator()),
      error: (e, _) => Text(
        '작성자 불러오기 실패',
        style: AppTextStyle.bodySmallStyle.copyWith(color: AppColors.textSecondary),
      ),
      data: (mini) {
        final nickname = mini?.nickname.isNotEmpty == true ? mini!.nickname : '';
        final photoUrl = mini?.photoUrl;

        return  ListTile(
          leading: CommonProfileAvatar(
            imageUrl: photoUrl,
            size: 40,
            uid: uid,
            gender: mini!.gender,
          ),
          title: Text(
            nickname,
            style: AppTextStyle.titleSmallMediumStyle,
          ),
        );
      },
    );

  }
}
