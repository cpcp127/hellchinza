import 'package:cached_network_image/cached_network_image.dart';
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

final userByUidProvider = FutureProvider.family<UserModel?, String>((
  ref,
  uid,
) async {
  final doc = await FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .get();
  if (!doc.exists) return null;
  return UserModel.fromFirestore(doc.data()!); // ✅ 너 변환 함수에 맞춰
});

class ProfileView extends ConsumerStatefulWidget {
  const ProfileView({super.key, this.uid});

  /// null이면 내 프로필
  final String? uid;

  @override
  ConsumerState createState() => _ProfileViewState();
}

class _ProfileViewState extends ConsumerState<ProfileView> {
  @override
  Widget build(BuildContext context) {
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    return Scaffold(
      appBar: AppBar(),
      body: Builder(
        builder: (context) {
          if (myUid == null) {
            return Center(
              child: Text(
                '로그인이 필요합니다',
                style: AppTextStyle.bodyMediumStyle.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            );
          }

          final uidToShow = widget.uid ?? myUid;
          final isMe = uidToShow == myUid;

          // ✅ 내 프로필은 기존 provider 그대로 사용
          if (isMe) {
            final my = ref.watch(myUserModelProvider);
            return _buildBody(context, my, isMe: true);
          }

          // ✅ 남 프로필은 uid로 가져오기
          final async = ref.watch(userByUidProvider(uidToShow));

          return async.when(
            loading: () => const Center(child: CupertinoActivityIndicator()),
            error: (e, _) => Center(child: Text('error: $e')),
            data: (user) {
              if (user == null) {
                return Center(
                  child: Text(
                    '사용자가 없어요',
                    style: AppTextStyle.bodyMediumStyle.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                );
              }
              return _buildBody(context, user, isMe: false);
            },
          );
        },
      ),
    );
  }

  /// ✅ 너가 올린 UI 구조를 그대로 유지하되
  /// FirebaseAuth.instance.currentUser!.uid 부분만 user.uid로 바꾸면 됨
  Widget _buildBody(
    BuildContext context,
    UserModel user, {
    required bool isMe,
  }) {
    final uid = user.uid;

    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),

            // ✅ 기존 카드 그대로, 편집 버튼만 isMe일 때
            buildProfileCard(user, showEdit: isMe),

            const SizedBox(height: 24),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Builder(
                builder: (context) {
                  final myFeedPreviewQuery = FirebaseFirestore.instance
                      .collection('feeds')
                      .where('authorUid', isEqualTo: uid)
                      .where('meetId', isNull: true)
                      .orderBy('createdAt', descending: true)
                      .limit(3);

                  final myFeedAllQuery = FirebaseFirestore.instance
                      .collection('feeds')
                      .where('authorUid', isEqualTo: uid)
                      .where('meetId', isNull: true)
                      .orderBy('createdAt', descending: true);

                  return FeedPreviewSection(
                    title: isMe ? '내가 작성한 피드' : '작성한 피드',
                    query: myFeedPreviewQuery,
                    emptyText: '아직 작성한 피드가 없어요',
                    onTapAll: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => MyFeedsListView(
                            title: isMe ? '내가 작성한 피드' : '작성한 피드',
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
                  final joinedPreviewQuery = FirebaseFirestore.instance
                      .collection('meets')
                      .where('memberUids', arrayContains: uid)
                      .where('authorUid', isNotEqualTo: uid)
                      .orderBy('dateTime')
                      .limit(3);

                  final joinedAllQuery = FirebaseFirestore.instance
                      .collection('meets')
                      .where('status', isEqualTo: 'open')
                      .where('memberUids', arrayContains: uid)
                      .where('authorUid', isNotEqualTo: uid)
                      .orderBy('dateTime');

                  return MeetPreviewSection(
                    title: isMe ? '내가 참가한 모임' : '참가한 모임',
                    query: joinedPreviewQuery,
                    emptyText: '아직 참가한 모임이 없어요',
                    onTapAll: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => MyMeetsListView(
                            title: isMe ? '내가 참가한 모임' : '참가한 모임',
                            query: joinedAllQuery,
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
                  final hostedPreviewQuery = FirebaseFirestore.instance
                      .collection('meets')
                      .where('authorUid', isEqualTo: uid)
                      .orderBy('createdAt', descending: true)
                      .limit(3);

                  final hostedAllQuery = FirebaseFirestore.instance
                      .collection('meets')
                      .where('status', isEqualTo: 'open')
                      .where('authorUid', isEqualTo: uid)
                      .orderBy('createdAt', descending: true);

                  return MeetPreviewSection(
                    title: isMe ? '내가 만든 모임' : '만든 모임',
                    query: hostedPreviewQuery,
                    emptyText: '아직 만든 모임이 없어요',
                    onTapAll: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => MyMeetsListView(
                            title: isMe ? '내가 만든 모임' : '만든 모임',
                            query: hostedAllQuery,
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  /// ✅ 기존 buildProfileCard를 그대로 쓰되 showEdit만 추가
  Widget buildProfileCard(UserModel user, {required bool showEdit}) {
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
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    user.photoUrl == null
                        ? Container(
                            width: 70,
                            height: 70,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.bgSecondary,
                            ),
                            child: Center(child: Icon(Icons.person)),
                          )
                        : Container(
                            width: 70,
                            height: 70,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              image: DecorationImage(
                                image: CachedNetworkImageProvider(
                                  user.photoUrl!,
                                ),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        (user.nickname?.isNotEmpty == true)
                            ? user.nickname!
                            : '닉네임 없음',
                        style: AppTextStyle.headlineSmallBoldStyle.copyWith(
                          color: AppColors.textDefault,
                        ),
                      ),
                    ),

                    if (showEdit)
                      _buildEditButton(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ProfileEditView(),
                            ),
                          );
                        },
                      ),
                  ],
                ),

                const SizedBox(height: 14),

                Text(
                  '소개',
                  style: AppTextStyle.titleSmallBoldStyle.copyWith(
                    color: AppColors.textDefault,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  (user.description?.trim().isNotEmpty == true)
                      ? user.description!
                      : '자기소개를 입력해 주세요',
                  style: AppTextStyle.bodyMediumStyle.copyWith(
                    color: (user.description?.trim().isNotEmpty == true)
                        ? AppColors.textSecondary
                        : AppColors.textLabel,
                  ),
                ),

                const SizedBox(height: 14),

                Text(
                  '카테고리',
                  style: AppTextStyle.titleSmallBoldStyle.copyWith(
                    color: AppColors.textDefault,
                  ),
                ),
                const SizedBox(height: 8),

                if (user.category.isEmpty)
                  Text(
                    '카테고리를 선택해 주세요',
                    style: AppTextStyle.bodyMediumStyle.copyWith(
                      color: AppColors.textLabel,
                    ),
                  )
                else
                  CommonChipWrap(
                    items: user.category,
                    selectedItems: user.category,
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
