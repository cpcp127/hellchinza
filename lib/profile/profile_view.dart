import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hellchinza/auth/domain/user_model.dart';
import 'package:hellchinza/common/common_chip.dart';
import 'package:hellchinza/profile/profile_controller.dart';
import 'package:hellchinza/profile/profile_edit_view.dart';
import 'package:hellchinza/profile/widget/feed_preview_section.dart';
import 'package:hellchinza/profile/widget/meet_preview_section.dart';
import 'package:hellchinza/profile/widget/my_feed_list_view.dart';
import 'package:hellchinza/profile/widget/my_meets_list_view.dart';

import '../claim/claim_view.dart';
import '../claim/domain/claim_model.dart';
import '../common/common_action_sheet.dart';
import '../common/common_bottom_button.dart';
import '../common/common_text_field.dart';
import '../constants/app_colors.dart';
import '../constants/app_text_style.dart';
import '../services/dialog_service.dart';
import '../services/snackbar_service.dart';

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
  const ProfileView({super.key, required this.uid, this.fromHomeTab});

  /// null이면 내 프로필
  final String uid;
  final bool? fromHomeTab;

  @override
  ConsumerState createState() => _ProfileViewState();
}

class _ProfileViewState extends ConsumerState<ProfileView> {
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(profileControllerProvider(widget.uid));
    final controller = ref.read(profileControllerProvider(widget.uid).notifier);

    final myUid = FirebaseAuth.instance.currentUser?.uid;
    return Scaffold(
      appBar: widget.fromHomeTab == null || widget.fromHomeTab == false
          ? AppBar(
              actions: [
                if (widget.uid != myUid) ...[
                  IconButton(
                    icon: const Icon(
                      Icons.more_horiz,
                      color: AppColors.icDefault,
                    ),
                    onPressed: () {
                      _showUserMoreSheet(
                        context: context,
                        onReport: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ClaimView(
                                target: ClaimTarget(
                                  type: ClaimTargetType.user,
                                  // ✅ 없으면 추가
                                  targetId: widget.uid,
                                  targetOwnerUid: widget.uid,
                                  // 상대 uid
                                  title: '유저 신고',
                                  parentId: null,
                                ),
                              ),
                            ),
                          );
                        },
                        onBlock: () async {
                          final ok = await _confirmBlockDialog(context);
                          if (!ok) return;

                          try {
                            await ref
                                .read(
                                  profileControllerProvider(
                                    widget.uid,
                                  ).notifier,
                                )
                                .blockUser(targetUid: widget.uid); // ✅ 아래 3) 참고

                            SnackbarService.show(
                              type: AppSnackType.success,
                              message: '차단했어요',
                            );

                            Navigator.pop(context); // ✅ 차단 후 프로필 화면 닫고 싶으면
                          } catch (e) {
                            SnackbarService.show(
                              type: AppSnackType.error,
                              message: e.toString().replaceAll(
                                'Exception: ',
                                '',
                              ),
                            );
                          }
                        },
                      );
                    },
                  ),
                ],
              ],
            )
          : null,
      bottomNavigationBar: state.showFriendButton
          ? SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                child: CommonBottomButton(
                  title: state.friendButtonTitle,
                  enabled: state.friendButtonEnabled,
                  loading: state.isBusy,
                  onTap: () async {
                    // ✅ View는 메시지 입력만 받고 controller 호출
                    final msg =  await DialogService.showTextInput(
                      context: context,
                      title: '친구 신청',
                      hintText: '신청 메시지를 입력하세요',
                      confirmText: '보내기',
                    );
                    if (msg == null) return;

                    try {
                      await controller.sendFriendRequest(
                        requestText: msg,
                        otherUid: widget.uid,
                      );
                      SnackbarService.show(
                        type: AppSnackType.success,
                        message: '친구 신청을 보냈어요',
                      );
                    } catch (e) {
                      print(e);
                      SnackbarService.show(
                        type: AppSnackType.error,
                        message: e.toString().replaceAll('Exception: ', ''),
                      );
                    }
                  },
                ),
              ),
            )
          : null,
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

  Future<void> _showUserMoreSheet({
    required BuildContext context,

    VoidCallback? onBlock,
    VoidCallback? onReport,
  }) async {
    final items = <CommonActionSheetItem>[
      CommonActionSheetItem(
        icon: Icons.delete_outline,
        title: '차단하기',
        onTap: onBlock ?? () {},
        isDestructive: true,
      ),

      CommonActionSheetItem(
        icon: Icons.flag_outlined,
        title: '신고하기',
        onTap: onReport ?? () {},
        isDestructive: true,
      ),
    ];

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => CommonActionSheet(title: '유저', items: items),
    );
  }



  Future<bool> _confirmBlockDialog(BuildContext context) async {
    final result =  await DialogService.showConfirm(
      context: context,
      title:  '차단할까요?',
      message: '차단하면 서로 프로필/피드가 제한되고 친구도 끊어집니다.',
      confirmText: '차단하기',
      isDestructive: true,
    );


    return result == true;
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
