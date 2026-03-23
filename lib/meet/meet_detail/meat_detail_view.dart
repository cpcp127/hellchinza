import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../claim/domain/claim_model.dart';
import '../../../claim/presentation/claim_view.dart';
import '../../../common/common_action_sheet.dart';
import '../../../common/common_chip.dart';
import '../../../common/common_network_image.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_text_style.dart';
import '../../../services/dialog_service.dart';
import '../../../services/snackbar_service.dart';

import '../domain/lightning_model.dart';
import '../domain/meet_model.dart';
import '../lightning_create/lightning_create_view.dart';
import '../meet_list/meet_list_view.dart';

import '../providers/meet_provider.dart';
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
                await controller.onTapMeetPrimaryButton(context);
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
      } else if (meet.needApproval) {
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

  Future<void> _onTapMore({
    required BuildContext context,
    required MeetDetailState state,
    required MeetDetailController controller,
  }) async {
    if (state.meet == null) return;

    if (state.isOwner) {
      await _showMeetOwnerActionSheet(
        context: context,
        state: state,
        controller: controller,
      );
      return;
    }

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
        if (!context.mounted) return;
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

  Future<void> _showMeetOwnerActionSheet({
    required BuildContext context,
    required MeetDetailState state,
    required MeetDetailController controller,
  }) async {
    final meet = state.meet!;
    final items = <CommonActionSheetItem>[
      CommonActionSheetItem(
        icon: Icons.edit_outlined,
        title: '모임 수정',
        onTap: () async {
          Navigator.pop(context);
          await controller.onTapMeetPrimaryButton(context);
        },
      ),
      CommonActionSheetItem(
        icon: meet.status == 'open'
            ? Icons.lock_outline
            : Icons.lock_open_outlined,
        title: meet.status == 'open' ? '모임 종료' : '모임 다시 열기',
        onTap: () async {
          Navigator.pop(context);
          final ok = await _confirm(
            context,
            title: meet.status == 'open' ? '모임을 종료할까요?' : '모임을 다시 열까요?',
            message: meet.status == 'open'
                ? '더 이상 새로운 참가를 받을 수 없어요.'
                : '다시 참가를 받을 수 있어요.',
            destructive: meet.status == 'open',
          );
          if (!ok) return;

          if (meet.status == 'open') {
            await controller.closeMeet();
          } else {
            await controller.reopenMeet();
          }
        },
      ),
      CommonActionSheetItem(
        icon: Icons.delete_outline,
        title: '모임 삭제',
        onTap: () async {
          Navigator.pop(context);
          final ok = await _confirm(
            context,
            title: '모임을 삭제할까요?',
            message: '모임과 연결된 정보가 함께 사라질 수 있어요.',
            destructive: true,
          );
          if (!ok) return;

          await controller.deleteMeet();
          SnackbarService.show(
            type: AppSnackType.success,
            message: '모임을 삭제했어요',
          );
          if (!context.mounted) return;
          Navigator.pop(context);
        },
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
          ref.invalidate(meetLightningSectionProvider(meet.id));
          ref.invalidate(meetPhotoFeedSectionProvider(meet.id));
          await controller.init();
          await Future.delayed(const Duration(milliseconds: 250));
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
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
              _MeetChatEntryCard(locked: !state.isMember && !state.isOwner),
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
                const _LockedMeetContentPreview()
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _MemberPreviewRow(memberCount: state.memberCount),
                    const SizedBox(height: 16),
                    _MeetPhotoFeedSection(
                      meetId: meet.id,
                      state: state,
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
              const SizedBox(height: 20),
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
          error: (_, __) => const SizedBox.shrink(),
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

class _MeetPhotoFeedSection extends ConsumerWidget {
  const _MeetPhotoFeedSection({
    required this.state,
    required this.meetId,
    required this.onTapAll,
  });

  final MeetDetailState state;
  final String meetId;
  final VoidCallback onTapAll;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(meetPhotoFeedSectionProvider(meetId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('모임 피드', style: AppTextStyle.titleMediumBoldStyle),
            const Spacer(),
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
          loading: () => _buildPhotoGridSkeleton(),
          error: (_, __) => Padding(
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
              final feedId = ((data['id'] ?? data['_docId']) ?? '').toString();
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

            return _buildPhotoGrid(context: context, items: items);
          },
        ),
      ],
    );
  }

  String _ellipsis(String s, int max) {
    if (s.length <= max) return s;
    return '${s.substring(0, max)}...';
  }

  Widget _buildPhotoGridSkeleton() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 6,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 6,
        crossAxisSpacing: 6,
        childAspectRatio: 1,
      ),
      itemBuilder: (_, __) {
        return Container(
          decoration: BoxDecoration(
            color: AppColors.bgSecondary,
            borderRadius: BorderRadius.circular(12),
          ),
        );
      },
    );
  }

  Widget _buildPhotoGrid({
    required BuildContext context,
    required List<_PhotoItem> items,
  }) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 6,
        crossAxisSpacing: 6,
        childAspectRatio: 1,
      ),
      itemBuilder: (_, index) {
        final item = items[index];

        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: item.imageUrl != null
              ? CommonNetworkImage(
                  imageUrl: item.imageUrl!,
                  fit: BoxFit.cover,
                  enableViewer: false,
                )
              : Container(
                  color: AppColors.bgSecondary,
                  padding: const EdgeInsets.all(10),
                  child: Center(
                    child: Text(
                      item.previewText ?? '',
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyle.bodySmallStyle.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
        );
      },
    );
  }
}

class _MeetChatEntryCard extends StatelessWidget {
  const _MeetChatEntryCard({required this.locked});

  final bool locked;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bgSecondary,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderSecondary),
      ),
      child: Row(
        children: [
          const Icon(Icons.chat_bubble_outline, color: AppColors.icDefault),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              locked ? '모임 참가 후 채팅방에 입장할 수 있어요' : '참가 후 채팅방을 이용할 수 있어요',
              style: AppTextStyle.bodyMediumStyle.copyWith(
                color: AppColors.textDefault,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MemberPreviewRow extends StatelessWidget {
  const _MemberPreviewRow({required this.memberCount});

  final int memberCount;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          '현재 $memberCount명 참여 중',
          style: AppTextStyle.bodyMediumStyle.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _LockedMeetContentPreview extends StatelessWidget {
  const _LockedMeetContentPreview();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        color: AppColors.bgSecondary,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderSecondary),
      ),
      child: Column(
        children: [
          const Icon(Icons.lock_outline, color: AppColors.icSecondary),
          const SizedBox(height: 8),
          Text(
            '참가하면 모임 피드와 번개를 볼 수 있어요',
            style: AppTextStyle.bodyMediumStyle.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _PhotoItem {
  final String feedId;
  final String? imageUrl;
  final String? previewText;

  const _PhotoItem({
    required this.feedId,
    required this.imageUrl,
    required this.previewText,
  });
}
