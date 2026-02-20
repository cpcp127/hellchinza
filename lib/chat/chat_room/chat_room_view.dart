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
    final isDm = widget.roomType == 'dm';
    final otherUid = ref.watch(otherUidProvider(widget.roomId));
    final otherAsync = (otherUid == null)
        ? const AsyncValue<UserMini?>.data(null)
        : ref.watch(userMiniProvider(otherUid));

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
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _ChatBubble(
                        roomId: widget.roomId,
                        roomType: widget.roomType,
                        data: data,
                        otherUser: otherAsync.value,
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
      title: isDm ? '채팅방을 나갈까요?' : '모임에서 나갈까요?',
      message: isDm
          ? '채팅방을 나가면 친구도 끊어집니다.\n정말 나가시겠어요?'
          : '모임에서 나가면 단톡방에서도 나가게 됩니다.\n정말 나가시겠어요?',
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
  final String roomType; // ✅ 추가
  final Map<String, dynamic> data;
  final Future<void> Function() onAccept;
  final Future<void> Function() onReject;
  final UserMini? otherUser;
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
      return Center(
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
      );
    }

    // friend_request
    if (type == 'friend_request') {
      final reqStatus = (data['requestStatus'] ?? 'pending').toString();
      final text = (data['text'] ?? '').toString();

      // ✅ 요청을 받은 사람에게만 버튼 노출(= 내가 sender가 아닐 때)
      final showAction = !isMine && reqStatus == 'pending';

      return Align(
        alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          width: 280,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isMine
                ? AppColors.btnPrimary.withOpacity(0.10)
                : AppColors.bgWhite,
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
        ),
      );
    }

    if (type == 'image') {
      final uploadStatus = (data['uploadStatus'] ?? 'done').toString();
      final imageUrl = data['imageUrl']?.toString();

      final isUploading =
          uploadStatus == 'uploading' && (imageUrl == null || imageUrl.isEmpty);

      Widget imageWidget;

      // ✅ 업로드 중이면: 로컬 파일로 즉시 표시(내 메시지에서만 의미 있음)
      if (isUploading &&
          pendingLocalPath != null &&
          pendingLocalPath!.isNotEmpty) {
        imageWidget = Image.file(File(pendingLocalPath!), fit: BoxFit.cover);
      } else if (imageUrl != null && imageUrl.isNotEmpty) {
        imageWidget = CommonNetworkImage(imageUrl: imageUrl, fit: BoxFit.cover);
      } else {
        // 다른 기기에서 업로드 중인데 로컬경로 없을 때(placeholder)
        imageWidget = Container(
          color: AppColors.bgSecondary,
          alignment: Alignment.center,
          child: const CupertinoActivityIndicator(),
        );
      }

      return Align(
        alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (isMine)
              Padding(
                padding: const EdgeInsets.only(right: 6, bottom: 2),
                child: Text(
                  timeText,
                  style: AppTextStyle.labelSmallStyle.copyWith(
                    color: AppColors.textTeritary,
                  ),
                ),
              ),

            if (!isMine) ...[
              CommonProfileAvatar(
                imageUrl: otherUser?.photoUrl,
                size: 28,
                uid: otherUser?.uid ?? '',
                gender: otherUser?.gender ?? 'unknown',
              ),
              const SizedBox(width: 4),
            ],

            // ✅ 이미지 버블
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                children: [
                  SizedBox(width: 220, height: 220, child: imageWidget),

                  // ✅ 업로드 중 오버레이(검은 오파시티 + 스피너)
                  if (isUploading)
                    Positioned.fill(
                      child: Container(
                        color: AppColors.black.withOpacity(0.28),
                        alignment: Alignment.center,
                        child: const CircularProgressIndicator(),
                      ),
                    ),

                  // ✅ 실패 표시(선택)
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
            ),

            if (!isMine)
              Padding(
                padding: const EdgeInsets.only(left: 6, bottom: 2),
                child: Text(
                  timeText,
                  style: AppTextStyle.labelSmallStyle.copyWith(
                    color: AppColors.textTeritary,
                  ),
                ),
              ),
          ],
        ),
      );
    }

    // text 기본
    final text = (data['text'] ?? '').toString();

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          // 카톡처럼 너무 길어지지 않게 (화면의 70~75% 정도)
          maxWidth: MediaQuery.of(context).size.width * 0.72,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // 상대방이면 시간 먼저
            if (isMine) ...[
              Padding(
                padding: const EdgeInsets.only(right: 6, bottom: 2),
                child: Text(
                  timeText,
                  style: AppTextStyle.labelSmallStyle.copyWith(
                    color: AppColors.textTeritary,
                  ),
                ),
              ),
            ],
            if (!isMine) ...[
              CommonProfileAvatar(
                imageUrl: otherUser?.photoUrl,
                size: 28,
                uid: otherUser?.uid ?? '',
                gender: otherUser?.gender ?? 'unknown',
              ),
              const SizedBox(width: 4),
            ],
            // ✅ 버블은 Flexible로 감싸서 줄바꿈 가능하게
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
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
              ),
            ),

            // 내 메시지면 시간 뒤에
            if (!isMine) ...[
              Padding(
                padding: const EdgeInsets.only(left: 6, bottom: 2),
                child: Text(
                  timeText,
                  style: AppTextStyle.labelSmallStyle.copyWith(
                    color: AppColors.textTeritary,
                  ),
                ),
              ),
            ],
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
                  ? () => chatController.pickAndSendOneImage()
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
