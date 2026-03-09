import 'dart:io';

import 'package:firebase_pagination/firebase_pagination.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../auth/domain/user_mini.dart';
import '../../auth/domain/user_mini_provider.dart';
import '../../claim/claim_view.dart';
import '../../claim/domain/claim_model.dart';
import '../../common/common_action_sheet.dart';
import '../../common/common_network_image.dart';
import '../../common/common_profile_avatar.dart';
import '../../common/common_text_field.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_text_style.dart';
import '../../services/dialog_service.dart';
import '../../services/snackbar_service.dart';
import 'chat_room_controller.dart';

class ChatView extends ConsumerStatefulWidget {
  const ChatView({
    super.key,
    required this.roomId,
    required this.roomType, // ✅ 추가: 'dm' | 'group'
    this.otherUid, // ✅ dm일 때만
    this.meetId, // ✅ group일 때만(없으면 roomId==meetId로 처리 가능)
  });

  final String roomId;
  final String roomType;
  final String? otherUid;
  final String? meetId;

  @override
  ConsumerState<ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends ConsumerState<ChatView>
    with WidgetsBindingObserver {
  final _textCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // ✅ 프레임 이후 실행(컨텍스트/리버팟 안정)
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final controller = ref.read(
        chatControllerProvider(widget.roomId).notifier,
      );

      await controller.enterRoom(); // unread 0 + activeAt 세팅
      controller.startHeartbeat(); // 15초마다 activeAt 갱신
    });
  }

  // ✅ 앱이 백그라운드/비활성화 되면 active 처리도 같이 정리(중요)
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = ref.read(chatControllerProvider(widget.roomId).notifier);

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      controller.leaveActive(); // 백그라운드로 가면 active 해제
    } else if (state == AppLifecycleState.resumed) {
      controller.enterRoom();
      controller.startHeartbeat();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _textCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(chatControllerProvider(widget.roomId));
    final controller = ref.read(chatControllerProvider(widget.roomId).notifier);

    final roomAsync = ref.watch(chatRoomProvider(widget.roomId));

    // 메시지 쿼리
    final query = FirebaseFirestore.instance
        .collection('chatRooms')
        .doc(widget.roomId)
        .collection('messages')
        .orderBy('createdAt', descending: true);

    final otherUid = ref.watch(otherUidProvider(widget.roomId));
    final otherAsync = (otherUid == null)
        ? const AsyncValue<UserMini?>.data(null)
        : ref.watch(userMiniProvider(otherUid));
    final usersMapAsync = ref.watch(chatRoomUsersMapProvider(widget.roomId));
    return Scaffold(
      appBar: AppBar(
        title: Text('채팅', style: AppTextStyle.titleMediumBoldStyle),

        actions: [
          IconButton(
            icon: const Icon(Icons.more_horiz, color: AppColors.icDefault),
            onPressed: () {
              if (widget.roomType == 'dm') {
                final other = widget.otherUid;
                if (other == null || other.isEmpty) return;

                _showChatMoreSheetDm(
                  context: context,
                  controller: controller,
                  roomId: widget.roomId,
                  otherUid: other,
                  onReport: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ClaimView(
                          target: ClaimTarget(
                            type: ClaimTargetType.user,
                            // ✅ 없으면 추가
                            targetId: otherUid!,
                            targetOwnerUid: otherUid,
                            // 상대 uid
                            title: '유저 신고',
                            parentId: null,
                          ),
                        ),
                      ),
                    );
                  },
                  onLeave: () async {
                    await showLeaveRoomDialog(
                      context: context,
                      controller: controller,
                      otherUid: widget.otherUid,
                      roomType: widget.roomType,
                    );
                  },
                );
              } else {
                _showChatMoreSheetGroup(
                  context: context,
                  controller: controller,
                  roomId: widget.roomId,
                  meetId: widget.meetId ?? widget.roomId,
                  onLeave: () async {
                    await showLeaveRoomDialog(
                      context: context,
                      controller: controller,

                      roomType: widget.roomType,
                    );
                  },
                );
              }
            },
          ),
        ],
      ),
      body: roomAsync.when(
        loading: () => const Center(child: CupertinoActivityIndicator()),
        error: (e, _) => Center(child: Text('error: $e')),
        data: (roomSnap) {
          final roomData = roomSnap.data();
          if (roomData == null) {
            return Center(
              child: Text(
                '채팅방이 없어요',
                style: AppTextStyle.bodyMediumStyle.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            );
          }

          // ✅ state.roomData도 갱신(선택: 화면에서 즉시 쓰고 싶으면)
          if (state.roomData != roomData) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              ref.read(chatControllerProvider(widget.roomId).notifier).state =
                  state.copyWith(roomData: roomData);
            });
          }

          final canSend = state.copyWith(roomData: roomData).canSend;

          return Column(
            children: [
              Expanded(
                child: FirestorePagination(
                  query: query,
                  limit: 20,
                  isLive: true,
                  reverse: true,
                  // 최근이 아래로 가게(패키지 옵션 없으면 직접 처리)
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),

                  /// ⚠️ 너가 말한 시그니처:
                  /// {required Widget Function(BuildContext, List<DocumentSnapshot<Object?>>, int) itemBuilder}
                  itemBuilder: (context, docs, index) {
                    final doc = docs[index];
                    final data = (doc.data() as Map<String, dynamic>? ?? {});
                    final msgId = (data['id'] ?? doc.id).toString();
                    final pendingPath = ref
                        .watch(chatControllerProvider(widget.roomId))
                        .pendingImageLocalPathByMsgId[msgId];

                    final currAt = controller.createdAtFrom(data);
                    DateTime? prevAt;

                    if (index + 1 < docs.length) {
                      final nextData = (docs[index + 1].data() as Map<String, dynamic>? ?? {});
                      prevAt = controller.createdAtFrom(nextData);
                    }

                    // ✅ 날짜 구분선 조건:
                    // - 이전 메시지와 "날짜가 다르면" 표시
                    final showDateDivider = currAt != null &&
                        ( prevAt == null || !controller.isSameDay(currAt, prevAt));
                    final authorUid = (data['authorUid'] ?? '').toString();
                    return usersMapAsync.when(
                      loading: () => const SizedBox.shrink(),
                      error: (e, _) => Text('유저 로딩 실패: $e'),
                      data: (usersMap) {
                        final authorMini = usersMap[authorUid]; // ✅ 보낸 사람 미니
                        return  Column(
                          children: [
                            if (showDateDivider) _buildDateDivider(currAt),
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _ChatBubble(
                                roomId: widget.roomId,
                                roomType: widget.roomType,
                                data: data,
                                otherUser: authorMini,
                                pendingLocalPath: pendingPath,
                                // ✅ 추가
                                onAccept: () async {
                                  try {
                                    await controller.acceptFriendRequest(
                                      requestMessageId: (data['id'] ?? doc.id)
                                          .toString(),
                                      otherUid: widget.otherUid!,
                                    );
                                    SnackbarService.show(
                                      type: AppSnackType.success,
                                      message: '수락했어요',
                                    );
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
                                onReject: () async {
                                  try {
                                    await controller.rejectFriendRequest(
                                      requestMessageId: (data['id'] ?? doc.id)
                                          .toString(),
                                    );
                                    SnackbarService.show(
                                      type: AppSnackType.success,
                                      message: '거절했어요',
                                    );
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
                              ),
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
              ),

              _ChatInputBar(
                enabled: canSend,
                controller: _textCtrl,
                roomId: widget.roomId,
                chatController: controller,
                onSend: () async {
                  try {
                    await controller.sendText(text: _textCtrl.text);
                    _textCtrl.clear();
                  } catch (e) {
                    SnackbarService.show(
                      type: AppSnackType.error,
                      message: e.toString().replaceAll('Exception: ', ''),
                    );
                  }
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDateDivider(DateTime day) {
    final controller = ref.read(chatControllerProvider(widget.roomId).notifier);
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 12),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.bgSecondary,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: AppColors.borderSecondary),
          ),
          child: Text(
            controller.formatDayKorean(day),
            style: AppTextStyle.labelSmallStyle.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showChatMoreSheetDm({
    required BuildContext context,
    required ChatController controller,
    required String roomId,
    required String otherUid,
    VoidCallback? onLeave,
    VoidCallback? onReport,
  }) async {
    final items = <CommonActionSheetItem>[
      CommonActionSheetItem(
        icon: Icons.delete_outline,
        title: '나가기',
        onTap: onLeave ?? () {},
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
      builder: (_) => CommonActionSheet(title: '채팅', items: items),
    );
  }

  Future<void> _showChatMoreSheetGroup({
    required BuildContext context,
    required ChatController controller,
    required String roomId,
    required String meetId,
    VoidCallback? onLeave,
  }) async {
    final items = <CommonActionSheetItem>[
      CommonActionSheetItem(
        icon: Icons.exit_to_app,
        title: '채팅방 나가기',
        onTap: onLeave ?? () {},
        isDestructive: true,
      ),
    ];

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => CommonActionSheet(title: '단톡', items: items),
    );
  }

  Future<void> _showChatMoreSheet({
    required BuildContext context,
    required ChatController controller,
    required String roomId,
    required String otherUid,
    VoidCallback? onLeave,
    VoidCallback? onReport,
  }) async {
    final items = <CommonActionSheetItem>[
      CommonActionSheetItem(
        icon: Icons.delete_outline,
        title: '나가기',
        onTap: onLeave ?? () {},
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
      builder: (_) => CommonActionSheet(title: '채팅', items: items),
    );
  }

  Future<void> showLeaveRoomDialog({
    required BuildContext context,
    required ChatController controller,
    required String roomType,
    String? otherUid, // DM에서만 필요
  }) async {
    final isDm = roomType == 'dm';

    final ok = await DialogService.showConfirm(
      context: context,
      title: '채팅방을 나갈까요?',
      message: isDm
          ? '채팅방을 나가면 친구도 끊어집니다.\n정말 나가시겠어요?'
          : '단톡방에서 나가면 모임에서도 나가게 됩니다.\n정말 나가시겠어요?',
      confirmText: '나가기',
      isDestructive: true,
    );

    if (ok != true) return;

    final controller = ref.read(chatControllerProvider(widget.roomId).notifier);
    if (isDm) {
      if (otherUid == null) return;
      await controller.leaveRoomAndUnfriend(otherUid: otherUid);
    } else {
      await controller.leaveGroupRoomAndMeet();
    }

    if (mounted) Navigator.pop(context); // 방 화면 닫기
  }
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({
    required this.roomId,
    required this.data,
    required this.onAccept,
    required this.onReject,
    required this.otherUser,
    required this.pendingLocalPath,
    required this.roomType,
  });

  final String roomId;
  final String roomType; // 'dm' | 'group'
  final Map<String, dynamic> data;
  final Future<void> Function() onAccept;
  final Future<void> Function() onReject;
  final UserMini? otherUser; // ⚠️ DM 기준 상대. 그룹은 senderUid별로 따로 주입하는 게 정답
  final String? pendingLocalPath;

  @override
  Widget build(BuildContext context) {
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    final senderUid = (data['authorUid'] ?? '').toString();
    final type = (data['type'] ?? 'text').toString();
    final isMine = myUid != null && senderUid == myUid;

    // 시간
    String timeText = '';
    final ts = data['createdAt'];
    if (ts is Timestamp) {
      final dt = ts.toDate();
      final hh = dt.hour.toString().padLeft(2, '0');
      final mm = dt.minute.toString().padLeft(2, '0');
      timeText = '$hh:$mm';
    }

    // system
    if (type == 'system') {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.bgSecondary,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.borderSecondary),
            ),
            child: Text(
              (data['text'] ?? '').toString(),
              style: AppTextStyle.labelSmallStyle.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ),
      );
    }

    // ✅ 그룹일 때만 상대 닉네임 노출(카톡 스타일)
    final showName = !isMine && roomType == 'group';
    final displayName = (otherUser?.nickname ?? '').trim();

    // ✅ 메시지 본문 위젯 만들기(텍스트/이미지/친구요청)
    Widget messageWidget;

    if (type == 'friend_request') {
      final reqStatus = (data['requestStatus'] ?? 'pending').toString();
      final text = (data['text'] ?? '').toString();
      final showAction = !isMine && reqStatus == 'pending';

      messageWidget = Container(
        width: 280,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isMine ? AppColors.btnPrimary.withOpacity(0.10) : AppColors.bgWhite,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.borderSecondary),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '친구 신청',
              style: AppTextStyle.labelMediumStyle.copyWith(
                color: AppColors.textDefault,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              text.isEmpty ? '친구 신청 메시지' : text,
              style: AppTextStyle.bodySmallStyle.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Text(
                  timeText,
                  style: AppTextStyle.labelSmallStyle.copyWith(
                    color: AppColors.textTeritary,
                  ),
                ),
                const Spacer(),
                if (reqStatus == 'accepted')
                  Text(
                    '수락됨',
                    style: AppTextStyle.labelSmallStyle.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  )
                else if (reqStatus == 'rejected')
                  Text(
                    '거절됨',
                    style: AppTextStyle.labelSmallStyle.copyWith(
                      color: AppColors.textTeritary,
                    ),
                  ),
              ],
            ),
            if (showAction) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _SmallOutlineButton(
                      text: '거절',
                      onTap: () async => await onReject(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _SmallPrimaryButton(
                      text: '수락',
                      onTap: () async => await onAccept(),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      );
    } else if (type == 'image') {
      final uploadStatus = (data['uploadStatus'] ?? 'done').toString();
      final imageUrl = data['imageUrl']?.toString();
      final isUploading =
          uploadStatus == 'uploading' && (imageUrl == null || imageUrl.isEmpty);

      Widget imageWidget;

      if (isUploading && pendingLocalPath != null && pendingLocalPath!.isNotEmpty) {
        imageWidget = Image.file(File(pendingLocalPath!), fit: BoxFit.cover);
      } else if (imageUrl != null && imageUrl.isNotEmpty) {
        imageWidget = CommonNetworkImage(imageUrl: imageUrl, fit: BoxFit.cover, enableViewer: true);
      } else {
        imageWidget = Container(
          color: AppColors.bgSecondary,
          alignment: Alignment.center,
          child: const CupertinoActivityIndicator(),
        );
      }

      messageWidget = ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            SizedBox(width: 220, height: 220, child: imageWidget),

            if (isUploading)
              Positioned.fill(
                child: Container(
                  color: AppColors.black.withOpacity(0.28),
                  alignment: Alignment.center,
                  child: const CircularProgressIndicator(),
                ),
              ),

            if (uploadStatus == 'failed')
              Positioned.fill(
                child: Container(
                  color: AppColors.black.withOpacity(0.35),
                  alignment: Alignment.center,
                  child: Text(
                    '업로드 실패',
                    style: AppTextStyle.labelMediumStyle.copyWith(
                      color: AppColors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    } else {
      // text 기본
      final text = (data['text'] ?? '').toString();

      messageWidget = Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isMine ? AppColors.btnPrimary : AppColors.bgSecondary,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          text,
          softWrap: true,
          style: AppTextStyle.bodyMediumStyle.copyWith(
            color: isMine ? AppColors.white : AppColors.textDefault,
          ),
        ),
      );
    }

    // ✅ 카톡 스타일 레이아웃
    // - 내 메시지: (버블) (시간)
    // - 상대 메시지: (프로필) (닉네임) (버블) (시간)
    if (isMine) {
      return Padding(
        padding: const EdgeInsets.only(top: 2, bottom: 8),
        child: Align(
          alignment: Alignment.centerRight,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // 시간 (카톡은 버블 옆 아래)
              Padding(
                padding: const EdgeInsets.only(right: 6, bottom: 2),
                child: Text(
                  timeText,
                  style: AppTextStyle.labelSmallStyle.copyWith(
                    color: AppColors.textTeritary,
                  ),
                ),
              ),

              // 버블
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.72,
                ),
                child: messageWidget,
              ),
            ],
          ),
        ),
      );
    }

    // 상대 메시지
    return Padding(
      padding: const EdgeInsets.only(top: 2, bottom: 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 프로필
            CommonProfileAvatar(
              imageUrl: otherUser?.photoUrl,
              size: 32,
              uid: otherUser?.uid ?? senderUid,
              gender: otherUser?.gender ?? 'unknown',
            ),
            const SizedBox(width: 8),

            // 닉네임 + 버블
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (showName && displayName.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.only(left: 2, bottom: 4),
                      child: Text(
                        displayName,
                        style: AppTextStyle.labelSmallStyle.copyWith(
                          color: AppColors.textTeritary,
                        ),
                      ),
                    ),
                  ],

                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.72,
                          ),
                          child: messageWidget,
                        ),
                      ),
                      const SizedBox(width: 6),
                      // 시간
                      Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Text(
                          timeText,
                          style: AppTextStyle.labelSmallStyle.copyWith(
                            color: AppColors.textTeritary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
class _ChatInputBar extends ConsumerWidget {
  const _ChatInputBar({
    required this.enabled,
    required this.controller,
    required this.onSend,
    required this.chatController,
    required this.roomId,
  });

  final bool enabled;
  final TextEditingController controller;
  final VoidCallback onSend;
  final ChatController chatController;
  final String roomId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(chatControllerProvider(roomId));
    final chatController = ref.read(chatControllerProvider(roomId).notifier);

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: AppColors.bgWhite,
          border: Border(top: BorderSide(color: AppColors.borderSecondary)),
        ),
        child: Row(
          children: [
            // ✅ 이미지 버튼
            IconButton(
              onPressed: state.canSend
                  ? () => chatController.pickAndSendOneImage(context)
                  : null,
              icon: const Icon(
                Icons.image_outlined,
                color: AppColors.icDefault,
              ),
            ),

            Expanded(
              child: IgnorePointer(
                ignoring: !enabled,
                child: Opacity(
                  opacity: enabled ? 1 : 0.55,
                  child: CommonTextField(
                    controller: controller,
                    hintText: enabled ? '메시지를 입력하세요' : '친구가 되어야 메시지를 보낼 수 있어요',
                    maxLines: 1,
                    onChanged: (_) {},
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: enabled ? onSend : null,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: enabled ? AppColors.btnPrimary : AppColors.btnDisabled,
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: Icon(Icons.send, color: AppColors.white, size: 20),
              ),
            ),
          ],
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
          side: BorderSide(color: AppColors.borderSecondary),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          backgroundColor: AppColors.bgWhite,
        ),
        child: Text(
          text,
          style: AppTextStyle.labelMediumStyle.copyWith(
            color: AppColors.textDefault,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
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
          backgroundColor: AppColors.btnPrimary,
          disabledBackgroundColor: AppColors.btnDisabled,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        child: Text(
          text,
          style: AppTextStyle.labelMediumStyle.copyWith(
            color: AppColors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}
