import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_pagination/firebase_pagination.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hellchinza/chat/chat_room/chat_room_view.dart';

import '../../auth/domain/user_mini_provider.dart';
import '../../common/common_profile_avatar.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_text_style.dart';
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
          // ✅ 너 패키지: (context, docs, index)
          itemBuilder: (context, docs, index) {
            final doc = docs[index]; // ✅ List에서 하나 꺼내고

            final data =
                (doc.data() as Map?)?.cast<String, dynamic>() ??
                <String, dynamic>{};

            final roomId = (data['id'] ?? doc.id).toString();

            final userUids =
                (data['userUids'] as List?)
                    ?.map((e) => e.toString())
                    .toList() ??
                [];

            final otherUid = userUids.firstWhere(
              (e) => e != uid,
              orElse: () => '',
            );

            final lastMessage = (data['lastMessageText'] ?? '').toString();
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
                  print(roomId);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => ChatView(roomId: roomId, otherUid: otherUid,)),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ChatRoomRow extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {



    final subtitle = lastType == 'friend_request'
        ? '친구 요청: $lastMessage'
        : lastMessage;

    final timeText = (lastAt == null)
        ? ''
        : DateTimeUtil.formatRelative(lastAt!); // 너 포맷 유틸에 맞춰
    final asyncMini = ref.watch(userMiniProvider(otherUid));
    return asyncMini.when(
      data: (mini){
        if(mini==null) return Container();
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
                  imageUrl: mini.photoUrl,
                  size: 44,
                  uid: otherUid,
                  gender: mini.gender,
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
                              mini.nickname,
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
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
      loading: () => Center(child: CupertinoActivityIndicator()),
      error: (e, _) => Text(
        '작성자 불러오기 실패',
        style: AppTextStyle.bodySmallStyle.copyWith(
          color: AppColors.textSecondary,
        ),
      ),
    );

  }
}
