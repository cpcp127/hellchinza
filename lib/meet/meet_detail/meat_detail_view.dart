import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hellchinza/chat/chat_room/chat_room_view.dart';
import 'package:hellchinza/claim/claim_view.dart';
import 'package:hellchinza/common/common_chip.dart';
import 'package:hellchinza/common/common_network_image.dart';
import 'package:hellchinza/common/common_profile_avatar.dart';

import '../../auth/domain/user_mini.dart';
import '../../claim/domain/claim_model.dart';
import '../../common/common_action_sheet.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_text_style.dart';
import '../../feed/create_feed/create_feed_view.dart';
import '../../feed/feed_detail/feed_detail_view.dart';
import '../../services/dialog_service.dart';
import '../../services/snackbar_service.dart';
import '../domain/lightning_model.dart';
import '../domain/meet_model.dart';
import '../lightning_create/lightning_create_view.dart';
import '../meet_list/meet_list_view.dart';
import '../widget/lightning_card.dart';
import '../widget/manage_meet_sheet.dart';
import '../widget/meet_feed_list_view.dart';
import '../widget/meet_ligthning_list_view.dart';
import 'meat_detail_controller.dart';
import 'meat_detail_state.dart';

class MeetDetailView extends ConsumerStatefulWidget {
  const MeetDetailView({super.key, required this.meetId});

  final String meetId;

  @override
  ConsumerState<MeetDetailView> createState() => _MeetDetailViewState();
}

class _MeetDetailViewState extends ConsumerState<MeetDetailView> {
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(meetDetailControllerProvider(widget.meetId));
    final controller = ref.read(
      meetDetailControllerProvider(widget.meetId).notifier,
    );

    return Scaffold(
      backgroundColor: AppColors.bgWhite,
      appBar: AppBar(
        backgroundColor: AppColors.bgWhite,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text('모임 상세'),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_horiz, color: AppColors.icDefault),
            onPressed: () => _onTapMore(
              context: context,
              state: state,
              controller: controller,
            ),
          ),
        ],
      ),
      body: _buildBody(context: context, state: state, controller: controller),
      bottomNavigationBar: state.meet == null
          ? null
          : _buildBottomActionBar(
              context: context,
              state: state,
              onTapPrimary: () async {
                await controller.onTapMeetPrimaryButton(
                  state: state,
                  controller: controller,
                  context: context,
                );
              },
              onTapSecondary: state.isOwner
                  ? () {
                      _openManageRequestsSheet(
                        context: context,
                        controller: controller,
                        meetId: state.meet!.id,
                      );
                    }
                  : null,
            ),
    );
  }

  // ---------------------------
  // UI Builders (simple -> method)
  // ---------------------------

  Widget _buildBody({
    required BuildContext context,
    required MeetDetailState state,
    required MeetDetailController controller,
  }) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.meet == null) {
      return Center(
        child: Text(
          state.errorMessage ?? '모임이 없어요',
          style: AppTextStyle.bodyMediumStyle.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      );
    }

    return _MeetDetailBody(
      meet: state.meet!,
      state: state,
      controller: controller,
    );
  }

  Widget _buildBottomActionBar({
    required BuildContext context,
    required MeetDetailState state,
    required VoidCallback onTapPrimary,
    VoidCallback? onTapSecondary,
  }) {
    final meet = state.meet!;
    final bottom = MediaQuery.of(context).padding.bottom;

    String primaryText;
    bool primaryEnabled = true;

    if (state.isOwner) {
      primaryText = '모임 수정';
    } else {
      if (meet.status != 'open') {
        primaryText = '종료된 모임';
        primaryEnabled = false;
      } else if (state.isMember) {
        primaryText = '참가 취소';
      } else if (state.isFull) {
        primaryText = '정원 마감';
        primaryEnabled = false;
      } else if (meet.needApproval == true) {
        primaryText = state.isRequested ? '요청 취소' : '참가 요청';
      } else {
        primaryText = '참가하기';
      }
    }

    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + bottom),
      decoration: BoxDecoration(
        color: AppColors.bgWhite,
        border: Border(top: BorderSide(color: AppColors.borderSecondary)),
      ),
      child: Row(
        children: [
          if (state.isOwner && onTapSecondary != null) ...[
            Expanded(
              child: _buildOutlinedButton(
                text: '참가자 관리',
                onTap: onTapSecondary,
              ),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: _buildPrimaryButton(
              text: primaryText,
              enabled: primaryEnabled,
              onTap: primaryEnabled ? onTapPrimary : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrimaryButton({
    required String text,
    required bool enabled,
    VoidCallback? onTap,
  }) {
    return SizedBox(
      height: 52,
      child: ElevatedButton(
        onPressed: enabled ? onTap : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: enabled
              ? AppColors.btnPrimary
              : AppColors.btnDisabled,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Text(
          text,
          style: AppTextStyle.titleMediumBoldStyle.copyWith(
            color: AppColors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildOutlinedButton({
    required String text,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      height: 52,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: AppColors.borderSecondary),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          backgroundColor: AppColors.bgWhite,
        ),
        child: Text(
          text,
          style: AppTextStyle.titleMediumBoldStyle.copyWith(
            color: AppColors.textDefault,
          ),
        ),
      ),
    );
  }

  // ---------------------------
  // Actions / Sheets (simple -> method)
  // ---------------------------

  Future<void> _onTapMore({
    required BuildContext context,
    required MeetDetailState state,
    required MeetDetailController controller,
  }) async {
    if (state.meet == null) return;

    await _showMeetGuestActionSheet(
      context: context,
      isMember: state.isMember,
      onLeave: () async {
        final ok = await _confirm(
          context,
          title: '모임에서 나갈까요?',
          message: '참가 기록은 사라집니다.',
          destructive: true,
        );
        if (!ok) return;

        await controller.leaveMeet();
        SnackbarService.show(type: AppSnackType.success, message: '모임에서 나왔어요');
        Navigator.pop(context);
      },
      onReport: () {
        Navigator.push(
          context,
          CupertinoPageRoute(
            fullscreenDialog: true,
            builder: (context) {
              return ClaimView(
                target: ClaimTarget(
                  type: ClaimTargetType.meet,
                  targetId: state.meet!.id,
                  targetOwnerUid: state.meet!.authorUid,
                  title: state.meet!.title,
                  imageUrl: state.meet!.imageUrls.isNotEmpty
                      ? state.meet!.imageUrls.first
                      : null,
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _openManageRequestsSheet({
    required BuildContext context,
    required MeetDetailController controller,
    required String meetId,
  }) async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) {
        return ManageMeetSheet(
          meetId: meetId,
          onChanged: () async {
            ref.invalidate(meetRequestUidsProvider(meetId));
            ref.invalidate(meetMembersProvider(meetId));
            ref.invalidate(meetMemberCountProvider(meetId));
            await controller.init();
          },
        );
      },
    );
  }

  Future<void> _showMeetGuestActionSheet({
    required BuildContext context,
    required bool isMember,
    required VoidCallback onReport,
    VoidCallback? onLeave,
  }) async {
    final state = ref.watch(meetDetailControllerProvider(widget.meetId));
    final items = <CommonActionSheetItem>[
      if (isMember && onLeave != null)
        CommonActionSheetItem(
          icon: Icons.exit_to_app_outlined,
          title: '모임 나가기',
          onTap: onLeave,
          isDestructive: true,
        ),
      if (!state.isOwner)
        CommonActionSheetItem(
          icon: Icons.report_outlined,
          title: '신고하기',
          onTap: onReport,
          isDestructive: true,
        ),
    ];

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => CommonActionSheet(title: '더보기', items: items),
    );
  }

  Future<bool> _confirm(
    BuildContext context, {
    required String title,
    required String message,
    required bool destructive,
  }) async {
    final result = await DialogService.showConfirm(
      context: context,
      title: title,
      message: message,
      confirmText: '확인',
      isDestructive: destructive,
    );
    return result ?? false;
  }
}

// =======================================================
// Providers
// =======================================================

final meetLightningSectionProvider =
    FutureProvider.family<List<LightningModel>, String>((ref, meetId) async {
      final snap = await FirebaseFirestore.instance
          .collection('meets')
          .doc(meetId)
          .collection('lightnings')
          .where('status', isEqualTo: 'open')
          .orderBy('dateTime', descending: false)
          .limit(5)
          .get();

      return snap.docs.map((d) => LightningModel.fromDoc(d)).toList();
    });

final meetPhotoFeedSectionProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((
      ref,
      meetId,
    ) async {
      final snap = await FirebaseFirestore.instance
          .collection('feeds')
          .where('meetId', isEqualTo: meetId)
          .orderBy('createdAt', descending: true)
          .limit(9)
          .get();

      // doc.id가 필요해서 _docId로 같이 넣음
      return snap.docs.map((d) => {'_docId': d.id, ...d.data()}).toList();
    });

// =======================================================
// Body Widgets (not simple -> keep widget)
// =======================================================

class _MeetDetailBody extends ConsumerWidget {
  const _MeetDetailBody({
    required this.controller,
    required this.meet,
    required this.state,
  });

  final MeetDetailState state;
  final MeetModel meet;
  final MeetDetailController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final memberCountAsync = ref.watch(meetMemberCountProvider(meet.id));
    final shouldLockContent = !state.isMember && !state.isOwner;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: RefreshIndicator(
        color: AppColors.sky400,
        backgroundColor: AppColors.bgWhite,
        onRefresh: () async {
          ref.invalidate(meetMemberCountProvider(meet.id));
          await controller.init();
          await Future.delayed(const Duration(milliseconds: 250));
        },
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (meet.imageUrls.isNotEmpty) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: CommonNetworkImage(
                    imageUrl: meet.imageUrls.first,
                    width: double.infinity,
                    height: 180,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(height: 12),
              ],

              Text(meet.title, style: AppTextStyle.headlineSmallBoldStyle),
              const SizedBox(height: 6),
              CommonChip(label: meet.category, selected: true),
              const SizedBox(height: 6),

              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '주 활동 지역',
                    style: AppTextStyle.titleSmallBoldStyle.copyWith(
                      color: AppColors.textDefault,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      meet.regions.isEmpty
                          ? '없음'
                          : meet.regions.map((r) => r.fullName).join(', '),
                      style: AppTextStyle.titleSmallMediumStyle.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              Text(
                meet.intro,
                style: AppTextStyle.bodyMediumStyle.copyWith(
                  color: AppColors.textDefault,
                ),
              ),
              const SizedBox(height: 16),
              _MeetChatEntryCard(
                locked: !state.isMember && !state.isOwner,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChatView(
                        roomId: meet.chatRoomId!,
                        roomType: 'group',
                        meetId: meet.id,
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 16),

              Row(
                children: [
                  memberCountAsync.when(
                    data: (count) => Text(
                      '참가자 ${count}명',
                      style: AppTextStyle.titleMediumBoldStyle,
                    ),
                    loading: () => Text(
                      '참가자 -명',
                      style: AppTextStyle.titleMediumBoldStyle,
                    ),
                    error: (_, __) => Text(
                      '참가자 -명',
                      style: AppTextStyle.titleMediumBoldStyle,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '최대 ${meet.maxMembers}명',
                    style: AppTextStyle.titleSmallMediumStyle,
                  ),
                ],
              ),
              const SizedBox(height: 10),

              if (shouldLockContent)
                _LockedMeetContentPreview()
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _MemberPreviewRow(meetId: meet.id, hostUid: meet.authorUid),
                    const SizedBox(height: 16),
                    _MeetPhotoFeedSection(
                      meetId: meet.id,
                      state: state,
                      controller: controller,
                      onTapAll: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => MeetFeedListView(meetId: meet.id),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 18),
                    _MeetLightningSection(
                      meetId: meet.id,
                      isMeetMember: state.isMember,
                      onTapAll: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                MeetLightningListView(meetId: meet.id),
                          ),
                        );
                      },
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MeetLightningSection extends ConsumerWidget {
  const _MeetLightningSection({
    required this.meetId,
    required this.isMeetMember,
    required this.onTapAll,
  });

  final String meetId;
  final VoidCallback onTapAll;
  final bool isMeetMember;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(meetLightningSectionProvider(meetId));

    return Column(
      children: [
        Row(
          children: [
            Text('번개', style: AppTextStyle.titleMediumBoldStyle),
            const Spacer(),
            if (isMeetMember) ...[
              _buildMiniWriteChip(
                title: '번개 생성',
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => LightningCreateView(meetId: meetId),
                    ),
                  );
                  ref.invalidate(meetLightningSectionProvider(meetId));
                },
              ),
              const SizedBox(width: 6),
            ],
            TextButton(
              onPressed: onTapAll,
              child: Text(
                '전체보기',
                style: AppTextStyle.labelMediumStyle.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        async.when(
          loading: () => const SizedBox.shrink(),
          error: (e, _) => const SizedBox.shrink(),
          data: (all) {
            final now = DateTime.now();
            final items = <LightningModel>[];

            for (final m in all) {
              if (m.dateTime.isBefore(
                now.subtract(const Duration(minutes: 1)),
              )) {
                continue;
              }
              items.add(m);
              if (items.length >= 3) break;
            }

            if (items.isEmpty) {
              return Padding(
                padding: const EdgeInsets.only(top: 20, bottom: 20),
                child: Center(
                  child: Text(
                    '아직 번개 모임이 없어요. 첫 번개를 만들어보세요 ✍️',
                    style: AppTextStyle.bodySmallStyle.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ...items.map(
                  (m) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: LightningCard(
                      meetId: meetId,
                      model: m,
                      isMeetMember: isMeetMember,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildMiniWriteChip({
    required String title,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.bgSecondary,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppColors.borderSecondary),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.add, size: 16, color: AppColors.icDefault),
            const SizedBox(width: 4),
            Text(
              title,
              style: AppTextStyle.labelSmallStyle.copyWith(
                color: AppColors.textDefault,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MeetPhotoFeedSection extends StatelessWidget {
  const _MeetPhotoFeedSection({
    required this.state,
    required this.meetId,
    required this.onTapAll,
    required this.controller,
  });

  final MeetDetailState state;
  final String meetId;
  final VoidCallback onTapAll;
  final MeetDetailController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('모임 피드', style: AppTextStyle.titleMediumBoldStyle),
            const Spacer(),
            if (state.isMember) ...[
              Consumer(
                builder: (context, ref, _) {
                  return _buildMiniWriteChip(
                    title: '피드 작성',
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CreateFeedView(meetId: meetId),
                        ),
                      );
                      ref.invalidate(meetPhotoFeedSectionProvider(meetId));
                    },
                  );
                },
              ),
              const SizedBox(width: 6),
            ],
            TextButton(
              onPressed: onTapAll,
              child: Text(
                '전체보기',
                style: AppTextStyle.labelMediumStyle.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Consumer(
          builder: (context, ref, _) {
            final async = ref.watch(meetPhotoFeedSectionProvider(meetId));

            return async.when(
              loading: () => _buildPhotoGridSkeleton(),
              error: (e, _) => Padding(
                padding: const EdgeInsets.only(top: 20),
                child: Center(
                  child: Text(
                    '모임 피드를 불러오지 못했어요',
                    style: AppTextStyle.bodySmallStyle.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
              data: (docs) {
                final items = <_PhotoItem>[];

                for (final data in docs) {
                  final feedId = ((data['id'] ?? data['_docId']) ?? '')
                      .toString();

                  final urls = (data['imageUrls'] as List?)
                      ?.whereType<String>()
                      .toList();

                  final contents = (data['contents'] as String?)?.trim();

                  if (urls != null && urls.isNotEmpty) {
                    items.add(
                      _PhotoItem(
                        feedId: feedId,
                        imageUrl: urls.first,
                        previewText: null,
                      ),
                    );
                  } else {
                    final preview = (contents == null || contents.isEmpty)
                        ? '내용이 없어요'
                        : _ellipsis(contents, 42);

                    items.add(
                      _PhotoItem(
                        feedId: feedId,
                        imageUrl: null,
                        previewText: preview,
                      ),
                    );
                  }

                  if (items.length >= 9) break;
                }

                if (items.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 20),
                    child: Center(
                      child: Text(
                        '아직 모임 피드가 없어요. 첫 피드를 작성해보세요 ✍️',
                        style: AppTextStyle.bodySmallStyle.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  );
                }

                return _buildPhotoGrid(
                  context: context,
                  items: items,
                  onTapItem: (feedId) {
                    if (!state.isMember) {
                      SnackbarService.show(
                        type: AppSnackType.error,
                        message: '모임에 먼저 참가해야 해요',
                      );
                      return;
                    }
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => FeedDetailView(feedId: feedId),
                      ),
                    );
                  },
                );
              },
            );
          },
        ),
      ],
    );
  }

  String _ellipsis(String s, int max) {
    if (s.length <= max) return s;
    return '${s.substring(0, max)}…';
  }

  Widget _buildMiniWriteChip({
    required String title,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.bgSecondary,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppColors.borderSecondary),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.add, size: 16, color: AppColors.icDefault),
            const SizedBox(width: 4),
            Text(
              title,
              style: AppTextStyle.labelSmallStyle.copyWith(
                color: AppColors.textDefault,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoGrid({
    required BuildContext context,
    required List<_PhotoItem> items,
    required void Function(String feedId) onTapItem,
  }) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 1,
      ),
      itemBuilder: (_, i) {
        final item = items[i];

        return GestureDetector(
          onTap: () => onTapItem(item.feedId),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: item.hasImage
                ? CommonNetworkImage(
                    imageUrl: item.imageUrl!,
                    height: double.infinity,
                    fit: BoxFit.cover,
                    enableViewer: false,
                  )
                : _buildTextTile(text: item.previewText ?? ''),
          ),
        );
      },
    );
  }

  Widget _buildTextTile({required String text}) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.bgSecondary,
        border: Border.all(color: AppColors.borderSecondary),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.subject, size: 16, color: AppColors.icSecondary),
          const SizedBox(height: 6),
          Expanded(
            child: Text(
              text,
              maxLines: 5,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyle.bodySmallStyle.copyWith(
                color: AppColors.textDefault,
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoGridSkeleton() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 9,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 1,
      ),
      itemBuilder: (_, __) {
        return Container(
          decoration: BoxDecoration(
            color: AppColors.bgSecondary,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.borderSecondary),
          ),
        );
      },
    );
  }
}

// =======================================================
// Simple data model
// =======================================================

class _PhotoItem {
  final String feedId;
  final String? imageUrl;
  final String? previewText;

  const _PhotoItem({required this.feedId, this.imageUrl, this.previewText});

  bool get hasImage => imageUrl != null && imageUrl!.isNotEmpty;
}

// =======================================================
// Member preview (complex -> keep as widget)
// =======================================================

class _MemberPreviewRow extends StatefulWidget {
  const _MemberPreviewRow({
    required this.meetId,
    required this.hostUid,
    this.pageSize = 10,
  });

  final String meetId;
  final String hostUid;
  final int pageSize;

  @override
  State<_MemberPreviewRow> createState() => _MemberPreviewRowState();
}

class _MemberPreviewRowState extends State<_MemberPreviewRow> {
  final List<UserMini> _users = [];
  final Set<String> _loadedUids = {};

  DocumentSnapshot<Map<String, dynamic>>? _lastDoc;

  bool _isLoading = false;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _loadNext();
  }

  @override
  void didUpdateWidget(covariant _MemberPreviewRow oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.meetId != widget.meetId ||
        oldWidget.hostUid != widget.hostUid) {
      _users.clear();
      _loadedUids.clear();
      _lastDoc = null;
      _isLoading = false;
      _hasMore = true;
      _loadNext();
    }
  }

  Future<void> _loadNext() async {
    if (_isLoading || !_hasMore) return;

    setState(() => _isLoading = true);

    try {
      Query<Map<String, dynamic>> query = FirebaseFirestore.instance
          .collection('meets')
          .doc(widget.meetId)
          .collection('members')
          .orderBy('joinedAt', descending: false)
          .limit(widget.pageSize);

      if (_lastDoc != null) {
        query = query.startAfterDocument(_lastDoc!);
      }

      final memberSnap = await query.get();

      if (memberSnap.docs.isEmpty) {
        setState(() {
          _hasMore = false;
          _isLoading = false;
        });
        return;
      }

      _lastDoc = memberSnap.docs.last;
      if (memberSnap.docs.length < widget.pageSize) {
        _hasMore = false;
      }

      final uids = memberSnap.docs
          .map((d) => (d.data()['uid'] ?? d.id).toString())
          .where((uid) => uid.isNotEmpty && !_loadedUids.contains(uid))
          .toList();

      if (uids.isEmpty) {
        setState(() => _isLoading = false);
        return;
      }

      final userSnap = await FirebaseFirestore.instance
          .collection('users')
          .where('uid', whereIn: uids)
          .get();

      final fetched = <UserMini>[];

      for (final d in userSnap.docs) {
        try {
          fetched.add(UserMini.fromMap(d.data(), d.id));
        } catch (e) {
          debugPrint('skip invalid user doc: ${d.id}, error: $e');
        }
      }
      fetched.sort(
        (a, b) => uids.indexOf(a.uid).compareTo(uids.indexOf(b.uid)),
      );

      for (final u in fetched) {
        _loadedUids.add(u.uid);
      }

      setState(() {
        _users.addAll(fetched);
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_users.isEmpty && !_isLoading) {
      return _buildEmptyMemberBox();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bgSecondary,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderSecondary),
      ),
      child: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final u in _users) ...[
              _buildMemberAvatar(user: u, isHost: u.uid == widget.hostUid),
              const SizedBox(width: 10),
            ],
            if (_isLoading) ...[
              for (int i = 0; i < 3; i++) ...[
                _buildMemberAvatarSkeleton(),
                const SizedBox(width: 10),
              ],
            ],
            if (_hasMore && !_isLoading)
              _buildLoadMoreChip(
                text: '${widget.pageSize}명 더보기',
                onTap: _loadNext,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMemberAvatar({required UserMini user, required bool isHost}) {
    return SizedBox(
      // width: 56,
      child: Column(
        children: [
          CommonProfileAvatar(
            imageUrl: user.photoUrl,
            size: 40,
            uid: user.uid,
            gender: user.gender,
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              if (isHost) ...[
                Icon(Icons.star_rounded, size: 12, color: AppColors.sky400),
              ],
              Text(
                user.nickname,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: AppTextStyle.labelXSmallStyle.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMemberAvatarSkeleton() {
    return Column(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.gray100,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.borderSecondary),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: 46,
          height: 10,
          decoration: BoxDecoration(
            color: AppColors.gray100,
            borderRadius: BorderRadius.circular(6),
          ),
        ),
      ],
    );
  }

  Widget _buildLoadMoreChip({
    required String text,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.bgWhite,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppColors.borderSecondary),
        ),
        child: Text(
          text,
          style: AppTextStyle.labelSmallStyle.copyWith(
            color: AppColors.textPrimary,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyMemberBox() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bgSecondary,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderSecondary),
      ),
      child: Center(
        child: Text(
          '참가자가 없어요',
          style: AppTextStyle.bodySmallStyle.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _LockedMeetContentPreview extends StatelessWidget {
  const _LockedMeetContentPreview();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        IgnorePointer(
          ignoring: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildMemberPreviewPlaceholder(),
              const SizedBox(height: 16),
              _buildFeedSectionPlaceholder(),
              const SizedBox(height: 18),
              _buildLightningSectionPlaceholder(),
            ],
          ),
        ),

        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.bgWhite.withValues(alpha: 0.88),
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),

        Positioned.fill(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.lock_outline_rounded,
                  size: 28,
                  color: AppColors.icDefault,
                ),
                const SizedBox(height: 10),
                Text(
                  '모임에 참가해야 참가자,\n모임 피드, 번개를 볼 수 있어요',
                  textAlign: TextAlign.center,
                  style: AppTextStyle.titleSmallBoldStyle.copyWith(
                    color: AppColors.textDefault,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMemberPreviewPlaceholder() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bgSecondary,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderSecondary),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        child: Row(
          children: List.generate(6, (index) {
            return Padding(
              padding: EdgeInsets.only(right: index == 5 ? 0 : 10),
              child: Column(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.gray100,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.borderSecondary),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: 46,
                    height: 10,
                    decoration: BoxDecoration(
                      color: AppColors.gray100,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ],
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildFeedSectionPlaceholder() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('모임 피드', style: AppTextStyle.titleMediumBoldStyle),
            const Spacer(),
            Text(
              '전체보기',
              style: AppTextStyle.labelMediumStyle.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 6,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 1,
          ),
          itemBuilder: (_, __) {
            return Container(
              decoration: BoxDecoration(
                color: AppColors.gray100,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.borderSecondary),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildLightningSectionPlaceholder() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('번개', style: AppTextStyle.titleMediumBoldStyle),
            const Spacer(),
            Text(
              '전체보기',
              style: AppTextStyle.labelMediumStyle.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Column(
          children: List.generate(2, (index) {
            return Padding(
              padding: EdgeInsets.only(bottom: index == 1 ? 0 : 10),
              child: Container(
                height: 96,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppColors.bgSecondary,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.borderSecondary),
                ),
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Container(
                      width: 72,
                      height: double.infinity,
                      decoration: BoxDecoration(
                        color: AppColors.gray100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 72,
                            height: 12,
                            decoration: BoxDecoration(
                              color: AppColors.gray100,
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Container(
                            width: double.infinity,
                            height: 14,
                            decoration: BoxDecoration(
                              color: AppColors.gray100,
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            width: 120,
                            height: 12,
                            decoration: BoxDecoration(
                              color: AppColors.gray100,
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}

class _MeetChatEntryCard extends StatelessWidget {
  const _MeetChatEntryCard({required this.locked, required this.onTap});

  final bool locked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: locked ? null : onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: locked ? AppColors.bgSecondary : AppColors.sky50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: locked ? AppColors.borderSecondary : AppColors.borderPrimary,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: locked ? AppColors.gray100 : AppColors.sky50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                locked ? Icons.lock_outline : Icons.chat_bubble_outline,
                color: locked ? AppColors.icSecondary : AppColors.sky400,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    locked ? '모임 단톡방' : '모임 단톡방 바로가기',
                    style: AppTextStyle.titleSmallBoldStyle.copyWith(
                      color: AppColors.textDefault,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    locked ? '모임에 참가해야 단톡방에 입장할 수 있어요' : '참가 멤버와 바로 대화해보세요',
                    style: AppTextStyle.bodySmallStyle.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: locked ? AppColors.icSecondary : AppColors.icDefault,
            ),
          ],
        ),
      ),
    );
  }
}
