import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
import '../../services/snackbar_service.dart';
import '../../utils/confirm.dart';
import '../domain/lightning_model.dart';
import '../lightning_create/lightning_create_view.dart';
import '../widget/lightning_card.dart';
import '../widget/manage_request_sheet.dart';
import '../widget/meet_ligthning_list_view.dart';
import 'meat_detail_controller.dart';
import '../widget/meet_feed_list_view.dart';
import '../domain/meet_model.dart';
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
        title: Text('모임 상세'),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_horiz, color: AppColors.icDefault),
            onPressed: () async {
              if (state.isOwner) {
                // ✅ 내가 만든 모임
                await showMeetOwnerActionSheet(
                  context: context,

                  onDelete: () async {
                    final ok = await confirm(
                      context,
                      title: '모임을 삭제할까요?',
                      message: '삭제 후 되돌릴 수 없습니다.',
                      destructive: true,
                    );
                    if (!ok) return;

                    await controller.deleteMeet();
                    if (context.mounted) Navigator.pop(context);
                    SnackbarService.show(
                      type: AppSnackType.success,
                      message: '모임을 삭제했습니다.',
                    );
                  },
                );
              } else {
                // ✅ 남이 만든 모임
                await showMeetGuestActionSheet(
                  context: context,
                  isMember: state.isMember,
                  onLeave: () async {
                    Navigator.pop(context);

                    final ok = await confirm(
                      context,
                      title: '모임에서 나갈까요?',
                      message: '참가 기록은 사라집니다.',
                      destructive: true,
                    );
                    if (!ok) return;

                    await controller.leaveMeet();
                    SnackbarService.show(
                      type: AppSnackType.success,
                      message: '모임에서 나왔어요',
                    );
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
            },
          ),
        ],
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : (state.meet == null)
          ? Center(
              child: Text(
                state.errorMessage ?? '모임이 없어요',
                style: AppTextStyle.bodyMediumStyle.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            )
          : _MeetDetailBody(
              meet: state.meet!,
              state: state,
              controller: controller,
            ),
      bottomNavigationBar: state.meet == null
          ? null
          : _BottomActionBar(
              state: state,
              onTapPrimary: () async {
                controller.onTapMeetPrimaryButton(
                  state: state,
                  controller: controller,
                  context: context,
                );
              },
              onTapSecondary: state.isOwner
                  ? () {
                      openManageRequestsSheet(
                        context: context,
                        controller: controller,
                        meetId: state.meet!.id,
                      );
                    }
                  : null,
            ),
    );
  }

  Future<void> openManageRequestsSheet({
    required BuildContext context,
    required MeetDetailController controller,
    required String meetId,
  }) async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) {
        return ManageRequestsSheet(
          meetId: meetId,
          onChanged: () async {
            // ✅ 승인/거절 처리 후 호출됨
            ref.invalidate(meetRequestUidsProvider(meetId));
            await controller.init();
          },
        );
      },
    );
  }

  Future<void> showMeetOwnerActionSheet({
    required BuildContext context,

    required VoidCallback onDelete,
  }) async {
    final items = <CommonActionSheetItem>[
      CommonActionSheetItem(
        icon: Icons.delete_outline,
        title: '모임 삭제',
        onTap: onDelete,
        isDestructive: true, // ✅ 네 CommonActionSheetItem에 이런 옵션이 있으면 사용
      ),
    ];

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => CommonActionSheet(title: '모임 관리', items: items),
    );
  }
}

Future<void> showMeetGuestActionSheet({
  required BuildContext context,
  required bool isMember,

  required VoidCallback onReport,
  VoidCallback? onLeave,
}) async {
  final items = <CommonActionSheetItem>[
    if (isMember && onLeave != null)
      CommonActionSheetItem(
        icon: Icons.exit_to_app_outlined,
        title: '모임 나가기',
        onTap: onLeave,
        isDestructive: true,
      ),

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

class _BottomActionBar extends StatelessWidget {
  const _BottomActionBar({
    required this.state,
    required this.onTapPrimary,
    this.onTapSecondary,
  });

  final MeetDetailState state;
  final VoidCallback onTapPrimary;
  final VoidCallback? onTapSecondary;

  @override
  Widget build(BuildContext context) {
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
              child: _OutlinedButton(text: '참가자 관리', onTap: onTapSecondary!),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            flex: 1,
            child: _PrimaryButton(
              text: primaryText,
              enabled: primaryEnabled,
              onTap: primaryEnabled ? onTapPrimary : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({required this.text, required this.enabled, this.onTap});

  final String text;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
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
}

class _OutlinedButton extends StatelessWidget {
  const _OutlinedButton({required this.text, required this.onTap});

  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: AppColors.borderSecondary),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
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
}

class _MeetDetailBody extends StatelessWidget {
  const _MeetDetailBody({
    required this.controller,
    required this.meet,
    required this.state,
  });

  final MeetDetailState state;
  final MeetModel meet;
  final MeetDetailController controller;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: RefreshIndicator(
        color: AppColors.sky400,
        backgroundColor: AppColors.bgWhite,
        onRefresh: () async {
          controller.init();
          await Future.delayed(const Duration(milliseconds: 250));
        },
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            //padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
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
              //주 활동 지역
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
                meet.intro ?? '',
                style: AppTextStyle.bodyMediumStyle.copyWith(
                  color: AppColors.textDefault,
                ),
              ),

              const SizedBox(height: 16),

              // 참가자 미리보기(UID 리스트)
              Row(
                children: [
                  Text(
                    '참가자 ${meet.userUids.length}명',
                    style: AppTextStyle.titleMediumBoldStyle,
                  ),
                  Expanded(child: SizedBox()),
                  Text(
                    '최대 ${meet.maxMembers}명',
                    style: AppTextStyle.titleSmallMediumStyle,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _MemberPreviewRow(memberUids: meet.userUids),
              const SizedBox(height: 16),
              _MeetPhotoFeedSection(
                meetId: meet.id,
                state: state,
                controller: controller,
                onTapAll: () {
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
                      builder: (_) => MeetFeedListView(meetId: meet.id),
                    ),
                  );
                },
              ),
              const SizedBox(height: 18),

              _MeetLightningSection(
                meetId: meet.id,
                isMeetMember: state.isMember, // ✅ 추가
                onTapAll: () async {
                  if (!state.isMember) {
                    SnackbarService.show(
                      type: AppSnackType.error,
                      message: '모임에 먼저 참가해야 해요',
                    );
                    return;
                  }
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => MeetLightningListView(meetId: meet.id),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    final mm = dt.month.toString();
    final dd = dt.day.toString();
    final hh = dt.hour;
    final mi = dt.minute.toString().padLeft(2, '0');
    final isAm = hh < 12;
    final h12 = hh == 0 ? 12 : (hh > 12 ? hh - 12 : hh);
    final ap = isAm ? '오전' : '오후';
    return '$mm/$dd $ap $h12:$mi';
  }
}

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

class _MeetLightningSection extends ConsumerWidget {
  const _MeetLightningSection({
    required this.meetId,
    required this.isMeetMember,
    required this.onTapAll,
  });

  final String meetId;
  final VoidCallback onTapAll;
  final bool isMeetMember; // ✅ 추가
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
              _MiniWriteButton(
                title: '번개 생성',
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => LightningCreateView(meetId: meetId),
                    ),
                  );

                  // ✅ 작성 후 돌아오면: 이 섹션만 새로고침
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
          loading: () => Container(), // 기존처럼 조용히
          error: (e, _) => Container(),
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
}

class _MemberPreviewRow extends StatefulWidget {
  const _MemberPreviewRow({required this.memberUids, this.pageSize = 10});

  final List<String> memberUids;

  /// ✅ 10명씩
  final int pageSize;

  @override
  State<_MemberPreviewRow> createState() => _MemberPreviewRowState();
}

class _MemberPreviewRowState extends State<_MemberPreviewRow> {
  final List<UserMini> _users = [];
  final Set<String> _loadedUids = {};
  bool _isLoading = false;

  int _cursor = 0; // memberUids에서 어디까지 로드했는지

  @override
  void initState() {
    super.initState();
    _loadNext(); // 첫 10명 로드
  }

  @override
  void didUpdateWidget(covariant _MemberPreviewRow oldWidget) {
    super.didUpdateWidget(oldWidget);

    // memberUids가 바뀌면 초기화 후 재로딩
    if (!_listEquals(oldWidget.memberUids, widget.memberUids)) {
      _users.clear();
      _loadedUids.clear();
      _cursor = 0;
      _isLoading = false;
      _loadNext();
    }
  }

  bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  bool get _hasMore => _cursor < widget.memberUids.length;

  Future<void> _loadNext() async {
    if (_isLoading) return;
    if (!_hasMore) return;

    setState(() => _isLoading = true);

    try {
      // 다음 10개 슬라이스
      final end = (_cursor + widget.pageSize).clamp(
        0,
        widget.memberUids.length,
      );
      final slice = widget.memberUids.sublist(_cursor, end);

      // 중복 제거
      final need = slice.where((uid) => !_loadedUids.contains(uid)).toList();
      _cursor = end;

      if (need.isEmpty) {
        setState(() => _isLoading = false);
        return;
      }

      // ✅ whereIn 최대 10개 제한 -> pageSize=10이면 안전
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .where('uid', whereIn: need)
          .get();

      final fetched = snap.docs
          .map((d) => UserMini.fromMap(d.data(), d.id))
          .toList();

      // whereIn은 순서 보장 X → need 순서로 정렬
      fetched.sort(
        (a, b) => need.indexOf(a.uid).compareTo(need.indexOf(b.uid)),
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
    if (widget.memberUids.isEmpty) {
      return _EmptyMemberBox();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bgSecondary,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderSecondary),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ✅ 가로 스크롤 (overflow 방지)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // 로드된 사용자들
                for (final u in _users) ...[
                  _MemberAvatar(user: u),
                  const SizedBox(width: 10),
                ],

                // 로딩 중 스켈레톤(가로로)
                if (_isLoading) ...[
                  for (int i = 0; i < 3; i++) ...[
                    const _MemberAvatarSkeleton(),
                    const SizedBox(width: 10),
                  ],
                ],

                // ✅ 더보기 버튼 (아직 남아있으면)
                if (_hasMore && !_isLoading)
                  _LoadMoreChip(text: '10명 더보기', onTap: _loadNext),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadMoreChip extends StatelessWidget {
  const _LoadMoreChip({required this.text, required this.onTap});

  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
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
}

class _MemberAvatar extends StatelessWidget {
  const _MemberAvatar({required this.user});

  final UserMini user;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CommonProfileAvatar(
          imageUrl: user.photoUrl,
          size: 40,
          uid: user.uid,
          gender: user.gender,
        ),

        const SizedBox(height: 6),
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
    );
  }
}

class _MemberAvatarSkeleton extends StatelessWidget {
  const _MemberAvatarSkeleton();

  @override
  Widget build(BuildContext context) {
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
}

class _EmptyMemberBox extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
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
                  return _MiniWriteButton(
                    title: '피드 작성',
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CreateFeedView(meetId: meetId),
                        ),
                      );

                      // ✅ 작성 후 돌아오면: 이 섹션만 즉시 새로고침
                      ref.invalidate(meetPhotoFeedSectionProvider(meetId));

                      // (선택) meetDetail 전체를 다시 읽어야 하는 게 있으면
                      // controller.init();
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
              loading: () => _PhotoGridSkeleton(),
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

                return _PhotoGrid(
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
}

class _PhotoItem {
  final String feedId;
  final String? imageUrl;
  final String? previewText;

  const _PhotoItem({required this.feedId, this.imageUrl, this.previewText});

  bool get hasImage => imageUrl != null && imageUrl!.isNotEmpty;
}

class _PhotoGrid extends StatelessWidget {
  const _PhotoGrid({required this.items, required this.onTapItem});

  final List<_PhotoItem> items;
  final void Function(String feedId) onTapItem;

  @override
  Widget build(BuildContext context) {
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
                  )
                : _TextTile(text: item.previewText ?? ''),
          ),
        );
      },
    );
  }
}

class _TextTile extends StatelessWidget {
  const _TextTile({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
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
          // 작은 아이콘
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
}

class _PhotoGridSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
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

class _MiniWriteButton extends StatelessWidget {
  const _MiniWriteButton({required this.onTap, required this.title});

  final VoidCallback onTap;
  final String title;

  @override
  Widget build(BuildContext context) {
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
