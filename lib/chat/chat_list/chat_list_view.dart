import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_pagination/firebase_pagination.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hellchinza/chat/chat_room/chat_room_view.dart';
import 'package:hellchinza/common/common_home_app_bar.dart';
import 'package:hellchinza/common/common_network_image.dart';

import '../../auth/domain/user_mini_provider.dart';
import '../../common/common_profile_avatar.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_text_style.dart';
import '../../meet/domain/meet_summary_model.dart';
import '../../utils/date_time_util.dart';
import 'chat_list_controller.dart';

class ChatListView extends ConsumerWidget {
  const ChatListView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(chatListControllerProvider);
    final controller = ref.read(chatListControllerProvider.notifier);

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return Scaffold(
        body: Center(
          child: Text(
            '로그인이 필요합니다',
            style: AppTextStyle.bodyMediumStyle.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
      );
    }

    final query = controller.buildQuery();

    return Scaffold(
      appBar: AppBar(title: Text('채팅')),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            controller.refresh();
          },
          child: FirestorePagination(
            key: ValueKey('chat_list_${state.refreshTick}'),
            query: query,
            limit: 10,
            isLive: true,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            onEmpty: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.chat_bubble_outline_rounded,
                    size: 42,
                    color: AppColors.icDisabled,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '아직 채팅이 없어요',
                    style: AppTextStyle.titleSmallBoldStyle.copyWith(
                      color: AppColors.textDefault,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '친구 신청을 하거나 모임에 참가하면\n채팅이 여기 표시돼요 🙂',
                    textAlign: TextAlign.center,
                    style: AppTextStyle.bodySmallStyle.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            itemBuilder: (context, docs, index) {
              final doc = docs[index];

              final data =
                  (doc.data() as Map?)?.cast<String, dynamic>() ??
                  <String, dynamic>{};

              final roomId = (data['id'] ?? doc.id).toString();
              final roomType = (data['type'] ?? 'dm').toString(); // ✅ 추가

              final userUids =
                  (data['userUids'] as List?)
                      ?.map((e) => e.toString())
                      .toList() ??
                  [];

              final meetId = data['meetId']?.toString(); // ✅ group일 때 사용

              final otherUid = roomType == 'dm'
                  ? userUids.firstWhere((e) => e != uid, orElse: () => '')
                  : null;

              final lastMessage = (data['lastMessageText'] ?? '').toString();
              final lastType = (data['lastMessageType'] ?? 'text').toString();
              final status = (data['status'] ?? 'pending').toString();

              DateTime? lastAt;
              final ts = data['lastMessageAt'];
              if (ts is Timestamp) lastAt = ts.toDate();
              final unreadMap =
                  (data['unreadCountMap'] as Map?)?.cast<String, dynamic>() ??
                  {};
              final myUid = FirebaseAuth.instance.currentUser!.uid;

              final unreadCount = (unreadMap[myUid] ?? 0) as int;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _ChatRoomRow(
                  roomId: roomId,
                  roomType: roomType,
                  // ✅ 추가
                  otherUid: otherUid,
                  // dm만 사용
                  meetId: meetId,
                  // group만 사용
                  lastMessage: lastMessage,
                  lastType: lastType,
                  status: status,
                  unreadCount: unreadCount,
                  lastAt: lastAt,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChatView(
                          roomId: roomId,
                          roomType: roomType, // ✅ 추가
                          otherUid: otherUid, // dm이면 값 있음, group이면 null
                          meetId: meetId, // group이면 넣고, 없으면 null
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ChatRoomRow extends ConsumerWidget {
  const _ChatRoomRow({
    required this.roomId,
    required this.roomType, // ✅ 추가: 'dm' | 'group'
    this.otherUid, // ✅ dm에서만 필요
    this.meetId, // ✅ group에서만 필요
    required this.lastMessage,
    required this.lastType,
    required this.status,
    required this.lastAt,
    required this.onTap,
    required this.unreadCount,
  });

  final String roomId;
  final String roomType;
  final String? otherUid;
  final String? meetId;
  final int unreadCount;
  final String lastMessage;
  final String lastType;
  final String status;
  final DateTime? lastAt;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subtitle = lastType == 'friend_request'
        ? '친구 요청: $lastMessage'
        : lastMessage;

    final timeText = (lastAt == null)
        ? ''
        : DateTimeUtil.formatRelative(lastAt!);

    if (roomType == 'group') {
      final id = meetId ?? roomId; // ✅ 너 설계에서 roomId=meetId면 이걸로 OK
      final asyncMeet = ref.watch(meetSummaryProvider(id));

      return asyncMeet.when(
        data: (meet) {
          if (meet == null) return const SizedBox.shrink();

          return _BaseChatRoomTile(
            title: meet.title,
            subtitle: subtitle,
            timeText: timeText,
            imageUrl: meet.imageUrls!.first,
            onTap: onTap,
            unreadCount: unreadCount,
          );
        },
        loading: () => const Center(child: CupertinoActivityIndicator()),
        error: (e, _) => Text(
          '모임 불러오기 실패 $e',
          style: AppTextStyle.bodySmallStyle.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      );
    }

    // ✅ dm
    final uid = otherUid;
    if (uid == null) return const SizedBox.shrink();

    final asyncMini = ref.watch(userMiniProvider(uid));
    return asyncMini.when(
      data: (mini) {
        if (mini == null) return const SizedBox.shrink();

        return _BaseChatRoomTile(
          title: mini.nickname,
          subtitle: subtitle,
          timeText: timeText,
          imageUrl: mini.photoUrl,
          gender: mini.gender,
          uidForAvatar: uid,
          onTap: onTap,
          unreadCount: unreadCount,
        );
      },
      loading: () => const Center(child: CupertinoActivityIndicator()),
      error: (e, _) => Text(
        '작성자 불러오기 실패 $e',
        style: AppTextStyle.bodySmallStyle.copyWith(
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

class _BaseChatRoomTile extends StatelessWidget {
  const _BaseChatRoomTile({
    required this.title,
    required this.subtitle,
    required this.timeText,
    required this.imageUrl,
    required this.onTap,
    required this.unreadCount,

    this.uidForAvatar,
    this.gender,
  });

  final String title;
  final String subtitle;
  final String timeText;
  final String? imageUrl;
  final VoidCallback onTap;
  final int unreadCount;

  // dm에서만 쓰는 값(프로필 기본이미지 처리용)
  final String? uidForAvatar;
  final String? gender;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.bgWhite,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.borderSecondary),
        ),
        child: Row(
          children: [
            // ✅ dm이면 CommonProfileAvatar 그대로, group이면 썸네일 아바타로
            _LeadingAvatar(
              imageUrl: imageUrl,
              uid: uidForAvatar,
              gender: gender,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyle.titleSmallBoldStyle.copyWith(
                            color: AppColors.textDefault,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        timeText,
                        style: AppTextStyle.labelSmallStyle.copyWith(
                          color: AppColors.textTeritary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyle.bodySmallStyle.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                      if (unreadCount > 0) ...[
                        const SizedBox(height: 6),
                        _UnreadBadge(count: unreadCount),
                      ],
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

class _UnreadBadge extends StatelessWidget {
  const _UnreadBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final text = count > 99 ? '99+' : count.toString();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.btnPrimary,
        borderRadius: BorderRadius.circular(999),
      ),
      constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
      alignment: Alignment.center,
      child: Text(
        text,
        style: AppTextStyle.labelSmallStyle.copyWith(
          color: AppColors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _LeadingAvatar extends StatelessWidget {
  const _LeadingAvatar({required this.imageUrl, this.uid, this.gender});

  final String? imageUrl;
  final String? uid;
  final String? gender;

  @override
  Widget build(BuildContext context) {
    // uid가 있으면 DM 아바타로 취급
    if (uid != null) {
      return CommonProfileAvatar(
        imageUrl: imageUrl,
        size: 44,
        uid: uid!,
        gender: gender,
      );
    }

    // 그룹(모임) 썸네일
    // return ClipRRect(
    //   borderRadius: BorderRadius.circular(12),
    //   child: Container(
    //     width: 44,
    //     height: 44,
    //     decoration: BoxDecoration(
    //       color: AppColors.bgSecondary,
    //       border: Border.all(color: AppColors.borderSecondary),
    //     ),
    //     child: (imageUrl == null || imageUrl!.isEmpty)
    //         ? const Icon(Icons.groups, color: AppColors.icSecondary, size: 22)
    //         : Image.network(imageUrl!, fit: BoxFit.cover),
    //   ),
    // );
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: imageUrl == null
          ? Container()
          : CommonNetworkImage(
              imageUrl: imageUrl!,
              width: 44,
              height: 44,
              fit: BoxFit.cover,
            ),
    );
  }
}
