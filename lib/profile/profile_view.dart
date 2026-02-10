import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_pagination/firebase_pagination.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hellchinza/auth/domain/user_model.dart';
import 'package:hellchinza/common/common_chip.dart';
import 'package:hellchinza/profile/profile_edit_view.dart';
import 'package:hellchinza/profile/widget/feed_mini_card.dart';
import 'package:hellchinza/profile/widget/feed_preview_section.dart';
import 'package:hellchinza/profile/widget/meet_preview_section.dart';
import 'package:hellchinza/profile/widget/my_feed_list_view.dart';
import 'package:hellchinza/profile/widget/my_meets_list_view.dart';
import 'package:hellchinza/profile/widget/section_header.dart';

import '../common/common_feed_preview_card.dart';
import '../common/common_network_image.dart';
import '../common/common_profile_avatar.dart';
import '../constants/app_colors.dart';
import '../constants/app_text_style.dart';
import '../feed/domain/feed_model.dart';
import '../feed/feed_detail/feed_detail_view.dart';
import '../meet/meet_detail/meat_detail_view.dart';
import '../meet/domain/meet_model.dart';

class ProfileView extends ConsumerStatefulWidget {
  const ProfileView({super.key});

  @override
  ConsumerState createState() => _ProfileViewState();
}

class _ProfileViewState extends ConsumerState<ProfileView> {
  @override
  Widget build(BuildContext context) {
    UserModel my = ref.watch(myUserModelProvider);
    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 24),
            buildProfileCard(my),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Builder(
                builder: (context) {
                  final myFeedPreviewQuery = FirebaseFirestore.instance
                      .collection('feeds')
                      .where(
                        'authorUid',
                        isEqualTo: FirebaseAuth.instance.currentUser!.uid,
                      )
                      .where(
                        'meetId',
                        isNull: true,
                      ) // ✅ 모임 피드 제외 (meetId:null로 통일했으니 가능)
                      .orderBy('createdAt', descending: true)
                      .limit(3);
                  final myFeedAllQuery = FirebaseFirestore.instance
                      .collection('feeds')
                      .where(
                        'authorUid',
                        isEqualTo: FirebaseAuth.instance.currentUser!.uid,
                      )
                      .where('meetId', isNull: true)
                      .orderBy('createdAt', descending: true);
                  return FeedPreviewSection(
                    title: '내가 작성한 피드',
                    query: myFeedPreviewQuery,
                    emptyText: '아직 작성한 피드가 없어요',
                    onTapAll: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => MyFeedsListView(
                            title: '내가 작성한 피드',
                            query: myFeedAllQuery,
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Builder(
                builder: (context) {
                  final joinedQuery = FirebaseFirestore.instance
                      .collection('meets')
                      .where(
                        'memberUids',
                        arrayContains: FirebaseAuth.instance.currentUser!.uid,
                      )
                      .where(
                        'authorUid',
                        isNotEqualTo: FirebaseAuth.instance.currentUser!.uid,
                      )
                      .orderBy('dateTime')
                      .limit(3);
                  return MeetPreviewSection(
                    title: '내가 참가한 모임',
                    query: joinedQuery,
                    emptyText: '아직 참가한 모임이 없어요',
                    onTapAll: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => MyMeetsListView(
                            title: '내가 참가한 모임',
                            query: FirebaseFirestore.instance
                                .collection('meets')
                                .where('status', isEqualTo: 'open')
                                .where(
                                  'memberUids',
                                  arrayContains:
                                      FirebaseAuth.instance.currentUser!.uid,
                                ).where(
                              'authorUid',
                              isNotEqualTo: FirebaseAuth.instance.currentUser!.uid,
                            )
                                .orderBy('dateTime'),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),

            const SizedBox(height: 18),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Builder(
                builder: (context) {
                  final hostedQuery = FirebaseFirestore.instance
                      .collection('meets')
                      .where(
                        'authorUid',
                        isEqualTo: FirebaseAuth.instance.currentUser!.uid,
                      )
                      .orderBy('createdAt', descending: true)
                      .limit(3);
                  return MeetPreviewSection(
                    title: '내가 만든 모임',
                    query: hostedQuery,
                    emptyText: '아직 만든 모임이 없어요',
                    onTapAll: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => MyMeetsListView(
                            title: '내가 만든 모임',
                            query: FirebaseFirestore.instance
                                .collection('meets')
                                .where('status', isEqualTo: 'open')
                                .where('authorUid', isEqualTo: FirebaseAuth.instance.currentUser!.uid)
                                .orderBy('createdAt', descending: true),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            SizedBox(height: 20)
          ],
        ),
      ),
    );
  }

  Widget buildProfileCard(UserModel my) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.bgWhite,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.borderSecondary, width: 1),
          boxShadow: [
            BoxShadow(
              color: AppColors.black.withOpacity(0.04),
              offset: const Offset(0, 2),
              blurRadius: 8,
            ),
            BoxShadow(
              color: AppColors.black.withOpacity(0.02),
              offset: const Offset(0, 6),
              blurRadius: 20,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 상단: 아바타 + 닉네임 + 편집
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    CommonProfileAvatar(imageUrl: my.photoUrl, size: 70),

                    const SizedBox(width: 12),

                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            (my.nickname?.isNotEmpty == true)
                                ? my.nickname!
                                : '닉네임 없음',
                            style: AppTextStyle.headlineSmallBoldStyle.copyWith(
                              color: AppColors.textDefault,
                            ),
                          ),
                        ],
                      ),
                    ),

                    _buildEditButton(
                      onTap: () {
                        // TODO: 편집 페이지 이동

                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) {
                              return ProfileEditView();
                            },
                          ),
                        );
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // 소개
                Text(
                  '소개',
                  style: AppTextStyle.titleSmallBoldStyle.copyWith(
                    color: AppColors.textDefault,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  (my.description?.trim().isNotEmpty == true)
                      ? my.description!
                      : '자기소개를 입력해 주세요',
                  style: AppTextStyle.bodyMediumStyle.copyWith(
                    color: (my.description?.trim().isNotEmpty == true)
                        ? AppColors.textSecondary
                        : AppColors.textLabel,
                  ),
                ),

                const SizedBox(height: 14),

                // 카테고리
                Text(
                  '카테고리',
                  style: AppTextStyle.titleSmallBoldStyle.copyWith(
                    color: AppColors.textDefault,
                  ),
                ),
                const SizedBox(height: 8),

                if (my.category.isEmpty)
                  Text(
                    '카테고리를 선택해 주세요',
                    style: AppTextStyle.bodyMediumStyle.copyWith(
                      color: AppColors.textLabel,
                    ),
                  )
                else
                  CommonChipWrap(
                    items: my.category,
                    selectedItems: my.category,
                    onTap: (str) {},
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEditButton({required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(99),
          color: AppColors.btnSecondary,
          border: Border.all(color: AppColors.borderSecondary, width: 1),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.edit, size: 16, color: AppColors.icSecondary),
            const SizedBox(width: 6),
            Text(
              '편집',
              style: AppTextStyle.labelMediumStyle.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
