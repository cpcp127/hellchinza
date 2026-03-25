import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hellchinza/auth/domain/user_model.dart';
import 'package:hellchinza/auth/providers/user_provider.dart';
import 'package:hellchinza/claim/domain/claim_model.dart';
import 'package:hellchinza/claim/presentation/claim_view.dart';
import 'package:hellchinza/common/common_action_sheet.dart';
import 'package:hellchinza/common/common_bottom_button.dart';
import 'package:hellchinza/common/common_chip.dart';
import 'package:hellchinza/constants/app_colors.dart';
import 'package:hellchinza/constants/app_text_style.dart';
import 'package:hellchinza/meet/domain/meet_model.dart';
import 'package:hellchinza/oow_step/presentation/oow_step_view.dart';

import 'package:hellchinza/profile/profile_controller.dart';
import 'package:hellchinza/profile/profile_edit_view.dart';
import 'package:hellchinza/profile/profile_state.dart';
import 'package:hellchinza/profile/providers/profile_provider.dart';
import 'package:hellchinza/profile/widget/feed_preview_section.dart';
import 'package:hellchinza/profile/widget/friend_list_view.dart';
import 'package:hellchinza/profile/widget/meet_preview_section.dart';
import 'package:hellchinza/profile/widget/my_feed_list_view.dart';
import 'package:hellchinza/profile/widget/my_meets_list_view.dart';
import 'package:hellchinza/services/dialog_service.dart';
import 'package:hellchinza/services/snackbar_service.dart';

class ProfileView extends ConsumerStatefulWidget {
  const ProfileView({super.key, required this.uid, this.fromHomeTab});

  final String uid;
  final bool? fromHomeTab;

  @override
  ConsumerState<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends ConsumerState<ProfileView> {
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(profileControllerProvider(widget.uid));
    final controller = ref.read(profileControllerProvider(widget.uid).notifier);

    final myUid = FirebaseAuth.instance.currentUser?.uid;
    final uidToShow = widget.uid;
    final isMe = uidToShow == myUid;

    AsyncValue<UserModel?>? otherUserAsync;
    if (!isMe) {
      otherUserAsync = ref.watch(userByUidProvider(uidToShow));
    }

    return Scaffold(
      appBar: widget.fromHomeTab == true
          ? null
          : AppBar(
              actions: [
                if (!isMe && otherUserAsync != null)
                  otherUserAsync.when(
                    loading: () => const SizedBox(),
                    error: (_, __) => const SizedBox(),
                    data: (user) {
                      if (user == null) return const SizedBox();

                      return IconButton(
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
                                      targetId: widget.uid,
                                      targetOwnerUid: widget.uid,
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
                                await controller.blockUser(
                                  targetUid: widget.uid,
                                );

                                SnackbarService.show(
                                  type: AppSnackType.success,
                                  message: '차단했어요',
                                );

                                if (!context.mounted) return;
                                Navigator.pop(context);
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
                      );
                    },
                  ),
              ],
            ),
      bottomNavigationBar: _buildBottomBar(
        context: context,
        state: state,
        controller: controller,
        myUid: myUid,
        uidToShow: uidToShow,
        isMe: isMe,
        otherUserAsync: otherUserAsync,
      ),
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

          if (isMe) {
            final my = ref.watch(myUserModelProvider);
            return _buildBody(context, my, isMe: true);
          }

          return otherUserAsync!.when(
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

  Widget? _buildBottomBar({
    required BuildContext context,
    required ProfileState state,
    required ProfileController controller,
    required String? myUid,
    required String uidToShow,
    required bool isMe,
    required AsyncValue<UserModel?>? otherUserAsync,
  }) {
    if (myUid == null) return null;
    if (isMe) return null;
    if (!state.showFriendButton) return null;

    return otherUserAsync!.when(
      loading: () => null,
      error: (_, __) => null,
      data: (user) {
        if (user == null) return null;

        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            child: CommonBottomButton(
              title: state.friendButtonTitle,
              enabled: state.friendButtonEnabled,
              loading: state.isBusy,
              onTap: () async {
                final msg = await DialogService.showTextInput(
                  context: context,
                  title: '친구 신청',
                  hintText: '신청 메시지를 입력하세요',
                  confirmText: '보내기',
                );
                if (msg == null) return;

                try {
                  await controller.sendFriendRequest(
                    requestText: msg,
                    otherUid: uidToShow,
                  );
                  SnackbarService.show(
                    type: AppSnackType.success,
                    message: '친구 신청을 보냈어요',
                  );
                } catch (e) {
                  SnackbarService.show(
                    type: AppSnackType.error,
                    message: e.toString().replaceAll('Exception: ', ''),
                  );
                }
              },
            ),
          ),
        );
      },
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
    final result = await DialogService.showConfirm(
      context: context,
      title: '차단할까요?',
      message: '차단하면 서로 프로필/피드가 제한되고 친구도 끊어집니다.',
      confirmText: '차단하기',
      isDestructive: true,
    );

    return result == true;
  }

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
            buildProfileCard(user, showEdit: isMe),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Consumer(
                builder: (context, ref, child) {
                  final myUid = FirebaseAuth.instance.currentUser?.uid ?? '';
                  final isFriendAsync = ref.watch(isFriendProvider(uid));

                  return isFriendAsync.when(
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                    data: (isFriend) {
                      Query<Map<String, dynamic>> baseQuery = FirebaseFirestore
                          .instance
                          .collection('feeds')
                          .where('authorUid', isEqualTo: uid)
                          .where('meetId', isNull: true);

                      Query<Map<String, dynamic>> myFeedPreviewQuery;
                      Query<Map<String, dynamic>> myFeedAllQuery;

                      if (isMe || myUid == uid) {
                        myFeedPreviewQuery = baseQuery
                            .orderBy('createdAt', descending: true)
                            .limit(3);

                        myFeedAllQuery = baseQuery.orderBy(
                          'createdAt',
                          descending: true,
                        );
                      } else if (isFriend) {
                        myFeedPreviewQuery = baseQuery
                            .where('visibility', whereIn: ['public', 'friends'])
                            .orderBy('createdAt', descending: true)
                            .limit(3);

                        myFeedAllQuery = baseQuery
                            .where('visibility', whereIn: ['public', 'friends'])
                            .orderBy('createdAt', descending: true);
                      } else {
                        myFeedPreviewQuery = baseQuery
                            .where('visibility', isEqualTo: 'public')
                            .orderBy('createdAt', descending: true)
                            .limit(3);

                        myFeedAllQuery = baseQuery
                            .where('visibility', isEqualTo: 'public')
                            .orderBy('createdAt', descending: true);
                      }

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
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Consumer(
                builder: (context, ref, _) {
                  final previewAsync = ref.watch(
                    joinedMeetPreviewProvider(uid),
                  );
                  final allAsync = ref.watch(joinedMeetAllProvider(uid));

                  return previewAsync.when(
                    loading: () => MeetPreviewSection(
                      title: isMe ? '내가 참가한 모임' : '참가한 모임',
                      items: const [],
                      emptyText: '불러오는 중...',
                      onTapAll: null,
                    ),
                    error: (_, __) => MeetPreviewSection(
                      title: isMe ? '내가 참가한 모임' : '참가한 모임',
                      items: const [],
                      emptyText: '모임을 불러오지 못했어요',
                      onTapAll: null,
                    ),
                    data: (previewItems) {
                      return MeetPreviewSection(
                        title: isMe ? '내가 참가한 모임' : '참가한 모임',
                        items: previewItems,
                        emptyText: '참가한 모임이 없어요',
                        onTapAll: () {
                          final allItems =
                              allAsync.asData?.value ?? previewItems;
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => MyMeetsListView(
                                title: isMe ? '내가 참가한 모임' : '참가한 모임',
                                items: allItems,
                              ),
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Consumer(
                builder: (context, ref, _) {
                  final previewAsync = ref.watch(
                    hostedMeetPreviewProvider(uid),
                  );
                  final allAsync = ref.watch(hostedMeetAllProvider(uid));

                  return previewAsync.when(
                    loading: () => MeetPreviewSection(
                      title: isMe ? '내가 만든 모임' : '만든 모임',
                      items: const [],
                      emptyText: '불러오는 중...',
                      onTapAll: null,
                    ),
                    error: (_, __) => MeetPreviewSection(
                      title: isMe ? '내가 만든 모임' : '만든 모임',
                      items: const [],
                      emptyText: '모임을 불러오지 못했어요',
                      onTapAll: null,
                    ),
                    data: (previewItems) {
                      return MeetPreviewSection(
                        title: isMe ? '내가 만든 모임' : '만든 모임',
                        items: previewItems,
                        emptyText: '만든 모임이 없어요',
                        onTapAll: () {
                          final allItems =
                              allAsync.asData?.value ?? previewItems;
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => MyMeetsListView(
                                title: isMe ? '내가 만든 모임' : '만든 모임',
                                items: allItems,
                              ),
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget buildProfileCard(UserModel user, {required bool showEdit}) {
    Color _getRankColor(int rank) {
      switch (rank) {
        case 1:
          return const Color(0xFFFFC107);
        case 2:
          return const Color(0xFFB0BEC5);
        case 3:
          return const Color(0xFFCD7F32);
        default:
          return AppColors.sky400;
      }
    }

    IconData _getRankIcon(int rank) {
      switch (rank) {
        case 1:
          return Icons.workspace_premium_rounded;
        case 2:
          return Icons.looks_two_rounded;
        case 3:
          return Icons.looks_3_rounded;
        default:
          return Icons.emoji_events;
      }
    }

    final int? rank = user.lastWeeklyRank;

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
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        user.photoUrl == null
                            ? Container(
                                width: 70,
                                height: 70,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.bgSecondary,
                                ),
                                child: const Center(child: Icon(Icons.person)),
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
                        if (rank != null && rank >= 1 && rank <= 3)
                          Positioned(
                            right: -2,
                            bottom: -2,
                            child: Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _getRankColor(rank),
                                border: Border.all(
                                  color: AppColors.bgWhite,
                                  width: 2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.black.withOpacity(0.15),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Icon(
                                _getRankIcon(rank),
                                size: 14,
                                color: AppColors.white,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        user.nickname.isNotEmpty ? user.nickname : '닉네임 없음',
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
                              builder: (_) => const ProfileEditView(),
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
                    onTap: (_) {},
                  ),
                const SizedBox(height: 14),
                Builder(
                  builder: (context) {
                    final asyncCount = ref.watch(friendCountProvider(user.uid));
                    return asyncCount.when(
                      loading: () => Text(
                        '친구 -명',
                        style: AppTextStyle.labelMediumStyle.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      error: (_, __) => Text(
                        '친구 ?명',
                        style: AppTextStyle.labelMediumStyle.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      data: (count) => GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  FriendListView(targetUid: user.uid),
                            ),
                          );
                        },
                        child: Text(
                          '친구 $count명',
                          style: AppTextStyle.labelMediumStyle.copyWith(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
                if (user.workoutGoal != null) _WorkoutGoalButton(uid: user.uid),
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

class _WorkoutGoalButton extends StatelessWidget {
  const _WorkoutGoalButton({required this.uid});

  final String uid;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => OowStepView(uid: uid,isHome: false,)),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.bgWhite,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.borderSecondary),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.sky50,
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.fitness_center,
                size: 18,
                color: AppColors.sky400,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '오운완 기록 보기',
                style: AppTextStyle.titleSmallBoldStyle.copyWith(
                  color: AppColors.textDefault,
                ),
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.icSecondary),
          ],
        ),
      ),
    );
  }
}
