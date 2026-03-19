import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/domain/user_mini_provider.dart';
import '../../auth/domain/user_model.dart';
import '../../common/common_action_sheet.dart';
import '../../common/common_profile_avatar.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_text_style.dart';
import '../../services/snackbar_service.dart';

final meetRequestUidsProvider = FutureProvider.autoDispose
    .family<List<String>, String>((ref, meetId) async {
  final snap = await FirebaseFirestore.instance
      .collection('meets')
      .doc(meetId)
      .collection('requests')
      .where('status', isEqualTo: 'pending')
      .get();

  return snap.docs.map((d) => d.id).toList();
});

final meetMembersProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, meetId) async {
  final snap = await FirebaseFirestore.instance
      .collection('meets')
      .doc(meetId)
      .collection('members')
      .orderBy('joinedAt', descending: false)
      .get();

  return snap.docs.map((d) {
    final data = d.data();
    return {
      'uid': (data['uid'] ?? d.id).toString(),
      'role': (data['role'] ?? 'member').toString(),
      'joinedAt': data['joinedAt'],
    };
  }).toList();
});

class ManageMeetSheet extends ConsumerStatefulWidget {
  const ManageMeetSheet({
    super.key,
    required this.meetId,
    required this.onChanged,
  });

  final String meetId;
  final Future<void> Function() onChanged;

  @override
  ConsumerState<ManageMeetSheet> createState() => _ManageMeetSheetState();
}

class _ManageMeetSheetState extends ConsumerState<ManageMeetSheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.55,
      maxChildSize: 0.98,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.bgWhite,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 8),
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.gray200,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Text(
                      '모임 관리',
                      style: AppTextStyle.titleMediumBoldStyle.copyWith(
                        color: AppColors.textDefault,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, color: AppColors.icDefault),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              TabBar(
                controller: _tabController,
                labelColor: AppColors.textDefault,
                unselectedLabelColor: AppColors.textSecondary,
                indicatorColor: AppColors.sky400,
                tabs: const [
                  Tab(text: '참가 요청'),
                  Tab(text: '참가자'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _ManageRequestsTab(
                      meetId: widget.meetId,
                      onChanged: widget.onChanged,
                      scrollController: scrollController,
                    ),
                    _ManageMembersTab(
                      meetId: widget.meetId,
                      onChanged: widget.onChanged,
                      scrollController: scrollController,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ManageRequestsTab extends ConsumerWidget {
  const _ManageRequestsTab({
    required this.meetId,
    required this.onChanged,
    required this.scrollController,
  });

  final String meetId;
  final Future<void> Function() onChanged;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reqAsync = ref.watch(meetRequestUidsProvider(meetId));

    return reqAsync.when(
      loading: () {
        return const Center(child: CupertinoActivityIndicator());
      },
      error: (e, _) {
        return Center(child: Text('요청 불러오기 실패: $e'));
      },
      data: (uids) {
        if (uids.isEmpty) {
          return Center(
            child: Text(
              '대기 중인 요청이 없어요',
              style: AppTextStyle.bodyMediumStyle.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          );
        }

        return ListView.separated(
          controller: scrollController,
          padding: const EdgeInsets.only(top: 12, bottom: 24),
          itemCount: uids.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final uid = uids[index];
            return _RequestRow(
              meetId: meetId,
              uid: uid,
              onChanged: onChanged,
            );
          },
        );
      },
    );
  }
}

class _RequestRow extends StatefulWidget {
  const _RequestRow({
    required this.meetId,
    required this.uid,
    required this.onChanged,
  });

  final String meetId;
  final String uid;
  final Future<void> Function() onChanged;

  @override
  State<_RequestRow> createState() => _RequestRowState();
}

class _RequestRowState extends State<_RequestRow> {
  bool _busy = false;
  bool _approved = false;

  DocumentReference<Map<String, dynamic>> get _meetRef =>
      FirebaseFirestore.instance.collection('meets').doc(widget.meetId);

  Future<void> _approve() async {
    if (_busy || _approved) return;
    setState(() => _busy = true);

    try {
      final uidToApprove = widget.uid;
      final db = FirebaseFirestore.instance;

      final reqRef = _meetRef.collection('requests').doc(uidToApprove);
      final memberRef = _meetRef.collection('members').doc(uidToApprove);
      final roomRef = db.collection('chatRooms').doc(widget.meetId);

      await db.runTransaction((tx) async {
        final meetSnap = await tx.get(_meetRef);
        if (!meetSnap.exists) {
          throw Exception('모임이 없어요');
        }

        final meetData = meetSnap.data()!;
        final max = (meetData['maxMembers'] ?? 0) as int;
        final status = (meetData['status'] ?? 'open').toString();

        if (status != 'open') {
          throw Exception('종료된 모임이에요');
        }

        final reqSnap = await tx.get(reqRef);
        if (!reqSnap.exists) {
          throw Exception('이미 처리된 요청이에요');
        }

        final memberSnap = await tx.get(memberRef);
        if (memberSnap.exists) {
          tx.delete(reqRef);
          return;
        }

        final countSnap = await _meetRef.collection('members').count().get();
        final currentCount = countSnap.count ?? 0;
        if (currentCount >= max) {
          throw Exception('정원이 마감되었습니다');
        }

        final roomSnap = await tx.get(roomRef);
        if (!roomSnap.exists) {
          throw Exception('채팅방이 없어요');
        }

        final roomData = roomSnap.data() as Map<String, dynamic>;
        final roomUserUids = List<String>.from(roomData['userUids'] ?? []);
        final visibleUids = List<String>.from(roomData['visibleUids'] ?? []);
        final unreadCountMap = Map<String, dynamic>.from(
          roomData['unreadCountMap'] ?? {},
        );
        final activeAtMap = Map<String, dynamic>.from(
          roomData['activeAtMap'] ?? {},
        );

        tx.set(memberRef, {
          'uid': uidToApprove,
          'role': 'member',
          'status': 'approved',
          'joinedAt': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        if (!roomUserUids.contains(uidToApprove)) {
          roomUserUids.add(uidToApprove);
        }
        if (!visibleUids.contains(uidToApprove)) {
          visibleUids.add(uidToApprove);
        }

        unreadCountMap[uidToApprove] = 0;
        activeAtMap[uidToApprove] = FieldValue.serverTimestamp();

        tx.update(roomRef, {
          'userUids': roomUserUids,
          'visibleUids': visibleUids,
          'unreadCountMap': unreadCountMap,
          'activeAtMap': activeAtMap,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        final msgRef = roomRef.collection('messages').doc();
        tx.set(msgRef, {
          'id': msgRef.id,
          'authorUid': 'system',
          'type': 'system',
          'text': '새 참가자가 승인되어 입장했어요 ✅',
          'createdAt': FieldValue.serverTimestamp(),
        });

        tx.update(roomRef, {
          'lastMessageText': '새 참가자가 승인되어 입장했어요 ✅',
          'lastMessageType': 'system',
          'lastMessageAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        tx.update(_meetRef, {'updatedAt': FieldValue.serverTimestamp()});

        tx.delete(reqRef);
      });

      setState(() {
        _approved = true;
      });

      SnackbarService.show(type: AppSnackType.success, message: '승인했어요');

      final functions = FirebaseFunctions.instanceFor(
        region: 'asia-northeast3',
      );
      await functions.httpsCallable('sendMeetRequestApprovedNotification').call(
        {'meetId': widget.meetId, 'targetUid': uidToApprove},
      );

      await widget.onChanged();

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      SnackbarService.show(type: AppSnackType.error, message: e.toString());
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _reject() async {
    if (_busy || _approved) return;
    setState(() => _busy = true);

    try {
      await _meetRef.collection('requests').doc(widget.uid).delete();

      SnackbarService.show(type: AppSnackType.success, message: '거절했어요');

      final functions = FirebaseFunctions.instanceFor(
        region: 'asia-northeast3',
      );
      await functions.httpsCallable('sendMeetRequestRejectedNotification').call(
        {'meetId': widget.meetId, 'targetUid': widget.uid},
      );

      await widget.onChanged();
    } catch (e) {
      SnackbarService.show(type: AppSnackType.error, message: e.toString());
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        final userAsync = ref.watch(userMiniProvider(widget.uid));

        return userAsync.when(
          loading: () {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.bgWhite,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.borderSecondary),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.bgSecondary,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.borderSecondary),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: const Icon(
                        Icons.person,
                        color: AppColors.icDisabled,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '불러오는 중…',
                        style: AppTextStyle.titleSmallBoldStyle.copyWith(
                          color: AppColors.textTeritary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    _SmallOutlineButton(text: '거절', onTap: null),
                    const SizedBox(width: 8),
                    _SmallPrimaryButton(text: '승인', onTap: null),
                  ],
                ),
              ),
            );
          },
          error: (e, _) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.bgWhite,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.borderSecondary),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.bgSecondary,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.borderSecondary),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: const Icon(
                        Icons.person,
                        color: AppColors.icDisabled,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '사용자 정보를 불러오지 못했어요',
                        style: AppTextStyle.titleSmallBoldStyle.copyWith(
                          color: AppColors.textDefault,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
          data: (mini) {
            final nickname = mini?.nickname.isNotEmpty == true
                ? mini!.nickname
                : '';
            final photoUrl = mini?.photoUrl;

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
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
                      imageUrl: photoUrl,
                      size: 40,
                      uid: mini!.uid,
                      gender: mini.gender,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        nickname,
                        style: AppTextStyle.titleSmallBoldStyle.copyWith(
                          color: AppColors.textDefault,
                        ),
                      ),
                    ),
                    if (!_approved) ...[
                      const SizedBox(width: 10),
                      _SmallOutlineButton(
                        text: '거절',
                        onTap: _busy ? null : _reject,
                      ),
                      const SizedBox(width: 8),
                    ],
                    _SmallPrimaryButton(
                      text: _busy ? '처리중' : (_approved ? '승인완료' : '승인'),
                      onTap: (_busy || _approved) ? null : _approve,
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _SmallPrimaryButton extends StatelessWidget {
  const _SmallPrimaryButton({required this.text, required this.onTap});

  final String text;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: onTap == null
              ? AppColors.btnDisabled
              : AppColors.btnPrimary,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyle.labelMediumStyle.copyWith(color: AppColors.white),
        ),
      ),
    );
  }
}

class _SmallOutlineButton extends StatelessWidget {
  const _SmallOutlineButton({required this.text, required this.onTap});

  final String text;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          side: BorderSide(color: AppColors.borderSecondary),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyle.labelMediumStyle.copyWith(
            color: AppColors.textDefault,
          ),
        ),
      ),
    );
  }
}


class _ManageMembersTab extends ConsumerWidget {
  const _ManageMembersTab({
    required this.meetId,
    required this.onChanged,
    required this.scrollController,
  });

  final String meetId;
  final Future<void> Function() onChanged;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(meetMembersProvider(meetId));
    final myUid = ref.watch(myUserModelProvider).uid;

    return async.when(
      loading: () => const Center(child: CupertinoActivityIndicator()),
      error: (e, _) => Center(child: Text('참가자 불러오기 실패: $e')),
      data: (members) {
        if (members.isEmpty) {
          return Center(
            child: Text(
              '참가자가 없어요',
              style: AppTextStyle.bodyMediumStyle.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          );
        }

        return ListView.separated(
          controller: scrollController,
          padding: const EdgeInsets.only(top: 12, bottom: 24),
          itemCount: members.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final item = members[index];
            final uid = item['uid'] as String;
            final role = item['role'] as String;
            final isMe = uid == myUid;

            return _MemberManageRow(
              meetId: meetId,
              uid: uid,
              role: role,
              isMe: isMe,
              onChanged: onChanged,
            );
          },
        );
      },
    );
  }
}

class _MemberManageRow extends ConsumerStatefulWidget {
  const _MemberManageRow({
    required this.meetId,
    required this.uid,
    required this.role,
    required this.isMe,
    required this.onChanged,
  });

  final String meetId;
  final String uid;
  final String role;
  final bool isMe;
  final Future<void> Function() onChanged;

  @override
  ConsumerState<_MemberManageRow> createState() => _MemberManageRowState();
}

class _MemberManageRowState extends ConsumerState<_MemberManageRow> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(userMiniProvider(widget.uid));

    return userAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (e, _) => const SizedBox.shrink(),
      data: (mini) {
        if (mini == null) return const SizedBox.shrink();

        final isHost = widget.role == 'host';

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
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
                  size: 40,
                  uid: mini.uid,
                  gender: mini.gender,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          mini.nickname,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyle.titleSmallBoldStyle.copyWith(
                            color: AppColors.textDefault,
                          ),
                        ),
                      ),
                      if (isHost) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.sky50,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: AppColors.borderPrimary),
                          ),
                          child: Text(
                            '호스트',
                            style: AppTextStyle.labelSmallStyle.copyWith(
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (widget.isMe) ...[
                  Text(
                    '나',
                    style: AppTextStyle.labelSmallStyle.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ] else
                  ...[
                    if (_busy)
                      const SizedBox(
                        width: 24,
                        height: 24,
                        child: CupertinoActivityIndicator(),
                      )
                    else
                    _MemberActionButton(
                      enabled: !_busy,
                      onTap: () async {
                        await _openMemberActionSheet(
                          context: context,
                          nickname: mini.nickname,
                        );
                      },
                    ),
                  ],
              ],
            ),
          ),
        );
      },
    );
  }
  Future<void> _showKickDialog(BuildContext context, String nickname) async {
    final textCtrl = TextEditingController();

    final result = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            decoration: const BoxDecoration(
              color: AppColors.bgWhite,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 핸들
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.gray200,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  Text(
                    '$nickname님을 추방할까요?',
                    style: AppTextStyle.titleMediumBoldStyle,
                  ),

                  const SizedBox(height: 6),

                  Text(
                    '추방 사유를 입력해야 진행할 수 있어요',
                    style: AppTextStyle.bodySmallStyle.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),

                  const SizedBox(height: 14),

                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.bgSecondary,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.borderSecondary),
                    ),
                    child: TextField(
                      controller: textCtrl,
                      maxLines: 3,
                      style: AppTextStyle.bodyMediumStyle,
                      decoration: InputDecoration(
                        hintText: '예: 비매너 행동, 반복적인 광고 등',
                        hintStyle: AppTextStyle.bodyMediumStyle.copyWith(
                          color: AppColors.textTeritary,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.all(12),
                      ),
                    ),
                  ),

                  const SizedBox(height: 18),

                  Row(
                    children: [
                      Expanded(
                        child: _DialogOutlineButton(
                          text: '취소',
                          onTap: () => Navigator.pop(context),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _DialogDangerButton(
                          text: '추방하기',
                          onTap: () {
                            final reason = textCtrl.text.trim();
                            if (reason.isEmpty) return;
                            Navigator.pop(context, reason); // ✅ 여기서 닫힘
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (result == null || result.isEmpty) return;

    await _kickMember(reason: result);
  }

  Future<void> _openMemberActionSheet({
    required BuildContext context,
    required String nickname,
  }) async {
    if (_busy) return;

    final items = <CommonActionSheetItem>[
      CommonActionSheetItem(
        icon: Icons.verified_user_outlined,
        title: '호스트 넘기기',
        onTap: () async {
          await _transferHost(nickname);
        },
      ),
      CommonActionSheetItem(
        icon: Icons.remove_circle_outline,
        title: '추방하기',
        onTap: () async {
          await _showKickDialog(context, nickname);
        },
        isDestructive: true,
      ),
    ];

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => CommonActionSheet(
        title: '$nickname님 관리',
        items: items,
      ),
    );
  }

  Future<void> _kickMember({required String reason}) async {
    if (_busy) return;
    setState(() => _busy = true);

    try {
      final db = FirebaseFirestore.instance;
      final meetRef = db.collection('meets').doc(widget.meetId);
      final memberRef = meetRef.collection('members').doc(widget.uid);
      final roomRef = db.collection('chatRooms').doc(widget.meetId);

      final myNickname = ref.read(myUserModelProvider).nickname;

      await db.runTransaction((tx) async {
        final memberSnap = await tx.get(memberRef);
        if (!memberSnap.exists) {
          throw Exception('이미 모임에서 나간 사용자예요');
        }

        final roomSnap = await tx.get(roomRef);
        if (!roomSnap.exists) {
          throw Exception('채팅방이 없어요');
        }

        final roomData = roomSnap.data()!;
        final roomUserUids = List<String>.from(roomData['userUids'] ?? const []);
        final visibleUids = List<String>.from(roomData['visibleUids'] ?? const []);
        final unreadCountMap =
        Map<String, dynamic>.from(roomData['unreadCountMap'] ?? const {});
        final activeAtMap =
        Map<String, dynamic>.from(roomData['activeAtMap'] ?? const {});
        final chatPushOffMap =
        Map<String, dynamic>.from(roomData['chatPushOffMap'] ?? const {});

        tx.delete(memberRef);

        roomUserUids.remove(widget.uid);
        visibleUids.remove(widget.uid);
        unreadCountMap.remove(widget.uid);
        activeAtMap.remove(widget.uid);
        chatPushOffMap.remove(widget.uid);

        final systemText = '${myNickname}님이 사용자를 모임에서 내보냈어요';

        tx.update(roomRef, {
          'userUids': roomUserUids,
          'visibleUids': visibleUids,
          'unreadCountMap': unreadCountMap,
          'activeAtMap': activeAtMap,
          'chatPushOffMap': chatPushOffMap,
          'lastMessageText': systemText,
          'lastMessageType': 'system',
          'lastMessageAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        final msgRef = roomRef.collection('messages').doc();
        tx.set(msgRef, {
          'id': msgRef.id,
          'authorUid': 'system',
          'type': 'system',
          'text': systemText,
          'createdAt': FieldValue.serverTimestamp(),
        });

        tx.update(meetRef, {
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });

      final functions = FirebaseFunctions.instanceFor(region: 'asia-northeast3');
      await functions.httpsCallable('sendMeetMemberKickedNotification').call({
        'meetId': widget.meetId,
        'targetUid': widget.uid,
        'reason': reason,
      });

      SnackbarService.show(
        type: AppSnackType.success,
        message: '추방했어요',
      );

      ref.invalidate(meetMembersProvider(widget.meetId));
      await widget.onChanged();

      if (mounted) {
        Navigator.pop(context); // ✅ 바텀시트 닫기
      }
    } catch (e) {
      SnackbarService.show(type: AppSnackType.error, message: e.toString());
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _transferHost(String nickname) async {
    if (_busy) return;
    setState(() => _busy = true);

    try {
      final db = FirebaseFirestore.instance;
      final myUid = ref.read(myUserModelProvider).uid;
      final meetRef = db.collection('meets').doc(widget.meetId);
      final myMemberRef = meetRef.collection('members').doc(myUid);
      final targetMemberRef = meetRef.collection('members').doc(widget.uid);

      await db.runTransaction((tx) async {
        final meetSnap = await tx.get(meetRef);
        if (!meetSnap.exists) throw Exception('모임이 없어요');

        final targetSnap = await tx.get(targetMemberRef);
        if (!targetSnap.exists) throw Exception('대상 사용자가 없어요');

        tx.set(myMemberRef, {
          'role': 'member',
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        tx.set(targetMemberRef, {
          'role': 'host',
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        tx.update(meetRef, {
          'authorUid': widget.uid,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });

      final functions = FirebaseFunctions.instanceFor(region: 'asia-northeast3');
      await functions.httpsCallable('sendMeetHostTransferredNotification').call({
        'meetId': widget.meetId,
        'targetUid': widget.uid,
      });

      SnackbarService.show(
        type: AppSnackType.success,
        message: '$nickname님에게 호스트를 넘겼어요',
      );

      ref.invalidate(meetMembersProvider(widget.meetId));
      await widget.onChanged();

      if (mounted) {
        Navigator.pop(context); // ✅ 바텀시트 닫기
      }
    } catch (e) {
      SnackbarService.show(type: AppSnackType.error, message: e.toString());
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }
}

class _DialogDangerButton extends StatelessWidget {
  const _DialogDangerButton({
    required this.text,
    required this.onTap,
  });

  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.red100,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(
          text,
          style: AppTextStyle.labelMediumStyle.copyWith(
            color: AppColors.white,
          ),
        ),
      ),
    );
  }
}
class _DialogOutlineButton extends StatelessWidget {
  const _DialogOutlineButton({
    required this.text,
    required this.onTap,
  });

  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: AppColors.borderSecondary),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(
          text,
          style: AppTextStyle.labelMediumStyle.copyWith(
            color: AppColors.textDefault,
          ),
        ),
      ),
    );
  }
}
class _MemberActionButton extends StatelessWidget {
  const _MemberActionButton({
    required this.enabled,
    required this.onTap,
  });

  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          // color: enabled ? AppColors.bgSecondary : AppColors.gray100,
          shape: BoxShape.circle,
          // border: Border.all(color: AppColors.borderSecondary),
        ),
        child: Icon(
          Icons.more_horiz,
          size: 18,
          color: enabled ? AppColors.icDefault : AppColors.icDisabled,
        ),
      ),
    );
  }
}