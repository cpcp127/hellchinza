import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_pagination/firebase_pagination.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../common/common_profile_avatar.dart';
import '../constants/app_colors.dart';
import '../constants/app_text_style.dart';
import '../utils/date_time_util.dart';
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
        appBar: AppBar(
          title: Text('채팅', style: AppTextStyle.titleMediumBoldStyle),
        ),
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
      appBar: AppBar(
        title: Text('채팅', style: AppTextStyle.titleMediumBoldStyle),
      ),
      body: RefreshIndicator(
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

          // ✅ 너 패키지: (context, docs, index)
          itemBuilder: (context, docs, index) {
            final doc = docs[index]; // ✅ List에서 하나 꺼내고

            final data =
                (doc.data() as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};

            final roomId = (data['id'] ?? doc.id).toString();

            final userUids = (data['userUids'] as List?)
                ?.map((e) => e.toString())
                .toList() ??
                [];

            final otherUid = userUids.firstWhere(
                  (e) => e != uid,
              orElse: () => '',
            );

            final lastMessage = (data['lastMessage'] ?? '').toString();
            final lastType = (data['lastMessageType'] ?? 'text').toString();
            final status = (data['status'] ?? 'pending').toString();

            DateTime? lastAt;
            final ts = data['lastMessageAt'];
            if (ts is Timestamp) lastAt = ts.toDate();

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _ChatRoomRow(
                roomId: roomId,
                otherUid: otherUid,
                lastMessage: lastMessage,
                lastType: lastType,
                status: status,
                lastAt: lastAt,
                onTap: () {
                  // TODO: 채팅방 이동
                },
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ChatRoomRow extends StatelessWidget {
  const _ChatRoomRow({
    required this.roomId,
    required this.otherUid,
    required this.lastMessage,
    required this.lastType,
    required this.status,
    required this.lastAt,
    required this.onTap,
  });

  final String roomId;
  final String otherUid;

  final String lastMessage;
  final String lastType;
  final String status;
  final DateTime? lastAt;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // TODO: 여기에 UserMini FutureBuilder로 otherUid의 nick/photo 가져와서 넣기
    // 지금은 자리만 만들어둠
    final title = otherUid.isEmpty ? '알 수 없는 사용자' : '상대방';

    final subtitle = lastType == 'friend_request'
        ? '친구 요청: $lastMessage'
        : lastMessage;

    final timeText = (lastAt == null)
        ? ''
        : DateTimeUtil.formatRelative(lastAt!); // 너 포맷 유틸에 맞춰

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
            CommonProfileAvatar(
              imageUrl: null, // TODO other user photo
              size: 44,
              uid: otherUid,
              gender: 'male', // TODO: UserMini에서
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
                      if (status == 'pending') ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.bgSecondary,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.borderSecondary),
                          ),
                          child: Text(
                            '수락 대기',
                            style: AppTextStyle.labelSmallStyle.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
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
