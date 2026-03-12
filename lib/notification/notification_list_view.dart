import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_pagination/firebase_pagination.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/app_text_style.dart';
import '../feed/feed_detail/feed_detail_view.dart';
import '../meet/meet_detail/meat_detail_view.dart';
import '../utils/date_time_util.dart';
import 'app_notification_model.dart';

class NotificationListView extends StatelessWidget {
  const NotificationListView({super.key});

  Query<Map<String, dynamic>> _query(String uid) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .orderBy('createdAt', descending: true);
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      return Scaffold(
        backgroundColor: AppColors.bgWhite,
        appBar: AppBar(
          title: Text('알림', style: AppTextStyle.titleMediumBoldStyle),
          backgroundColor: AppColors.bgWhite,
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

    return Scaffold(
      backgroundColor: AppColors.bgWhite,
      appBar: AppBar(
        title: Text('알림', style: AppTextStyle.titleMediumBoldStyle),
        backgroundColor: AppColors.bgWhite,
      ),
      body: FirestorePagination(
        query: _query(uid),
        limit: 20,
        isLive: true,
        separatorBuilder: (_, __) => const Divider(height: 1),

        initialLoader: const Center(
          child: Padding(
            padding: EdgeInsets.only(top: 24),
            child: CupertinoActivityIndicator(),
          ),
        ),
        bottomLoader: const Padding(
          padding: EdgeInsets.symmetric(vertical: 14),
          child: Center(child: CupertinoActivityIndicator()),
        ),
        onEmpty: Center(
          child: Text(
            '아직 알림이 없어요',
            style: AppTextStyle.bodyMediumStyle.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),

        itemBuilder: (context, docs, index) {
          final doc = docs[index] as DocumentSnapshot<Map<String, dynamic>>;
          final model = AppNotificationModel.fromDoc(doc);

          return _NotificationTile(model: model);
        },
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.model});

  final AppNotificationModel model;

  Future<void> _markAsRead() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    if (model.isRead) return;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .doc(model.id)
        .update({'isRead': true});
  }

  Future<void> _onTap(BuildContext context) async {
    await _markAsRead();

    if (model.type == 'comment' || model.type == 'like') {
      if (model.feedId == null) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => FeedDetailView(feedId: model.feedId!),
        ),
      );
      return;
    }

    if (model.type == 'chat') {
      // TODO: 채팅방 이동
      return;
    }

    if (model.type == 'meet') {
      // TODO: 번개/모임 상세 이동
      switch (model.action) {
        case 'requestCreated':
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => MeetDetailView(meetId: model.meetId!),
            ),
          );
          return;

        case 'requestApproved':
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => MeetDetailView(meetId: model.meetId!),
            ),
          );
          return;

        case 'requestRejected':
          return;

        default:
          return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final timeText = model.createdAt == null
        ? ''
        : DateTimeUtil.formatRelative(model.createdAt!);

    return InkWell(
      onTap: () => _onTap(context),
      child: Container(
        color: model.isRead ? AppColors.bgWhite : AppColors.sky50,
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildLeadingIcon(),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          model.title ?? _defaultTitle(),
                          style: AppTextStyle.labelLargeStyle.copyWith(
                            color: AppColors.textDefault,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      if (!model.isRead)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppColors.red100,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    model.body ?? '',
                    style: AppTextStyle.bodyMediumStyle.copyWith(
                      color: AppColors.textDefault,
                    ),
                  ),
                  if ((model.contentPreview ?? '').isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.bgSecondary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        model.contentPreview!,
                        style: AppTextStyle.bodySmallStyle.copyWith(
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    timeText,
                    style: AppTextStyle.labelSmallStyle.copyWith(
                      color: AppColors.textTeritary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLeadingIcon() {
    IconData icon;
    Color bgColor;
    Color iconColor;

    switch (model.type) {
      case 'comment':
        icon = Icons.chat_bubble_outline;
        bgColor = AppColors.sky50;
        iconColor = AppColors.sky400;
        break;
      case 'like':
        icon = Icons.favorite_border;
        bgColor = AppColors.sky50;
        iconColor = AppColors.sky400;
        break;
      case 'chat':
        icon = Icons.forum_outlined;
        bgColor = AppColors.sky50;
        iconColor = AppColors.sky400;
        break;
      case 'meet':
        icon = Icons.people_rounded;
        bgColor = AppColors.sky50;
        iconColor = AppColors.sky400;
        break;
      default:
        icon = Icons.notifications_none;
        bgColor = AppColors.gray100;
        iconColor = AppColors.icDefault;
    }

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Icon(icon, size: 20, color: iconColor),
    );
  }

  String _defaultTitle() {
    switch (model.type) {
      case 'comment':
        return '새 댓글';
      case 'like':
        return '새 좋아요';
      case 'chat':
        return '새 메시지';
      case 'lightning':
        return '새 번개';
      default:
        return '알림';
    }
  }
}
