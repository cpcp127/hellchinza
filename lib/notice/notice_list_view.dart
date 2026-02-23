import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_pagination/firebase_pagination.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/app_colors.dart';
import '../constants/app_text_style.dart';
import 'notice_detail_view.dart';

class NoticeListView extends ConsumerWidget {
  const NoticeListView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = FirebaseFirestore.instance
        .collection('notices')
        .orderBy('createdAt', descending: true);

    return Scaffold(
      backgroundColor: AppColors.bgWhite,
      appBar: AppBar(
        title: Text(
          '공지사항',
          style: AppTextStyle.titleMediumBoldStyle,
        ),
      ),
      body: FirestorePagination(
        query: query,
        limit: 10,
        isLive: false,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        onEmpty: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.campaign_outlined,
                size: 42,
                color: AppColors.icDisabled,
              ),
              const SizedBox(height: 12),
              Text(
                '공지사항이 없습니다',
                style: AppTextStyle.titleSmallBoldStyle.copyWith(
                  color: AppColors.textDefault,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '새로운 공지가 등록되면 여기에 표시됩니다',
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
              (doc.data() as Map?)?.cast<String, dynamic>() ?? {};

          final title = (data['title'] ?? '').toString();
          final content = (data['content'] ?? '').toString();
          final isPinned = (data['isPinned'] ?? false) as bool;

          DateTime? createdAt;
          final ts = data['createdAt'];
          if (ts is Timestamp) createdAt = ts.toDate();

          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _NoticeTile(
              title: title,
              content: content,
              createdAt: createdAt,
              isPinned: isPinned,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => NoticeDetailView(
                      title: title,
                      content: content,
                      createdAt: createdAt,
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _NoticeTile extends StatelessWidget {
  const _NoticeTile({
    required this.title,
    required this.content,
    required this.createdAt,
    required this.isPinned,
    required this.onTap,
  });

  final String title;
  final String content;
  final DateTime? createdAt;
  final bool isPinned;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dateText = createdAt == null
        ? ''
        : '${createdAt!.year}.${createdAt!.month.toString().padLeft(2, '0')}.${createdAt!.day.toString().padLeft(2, '0')}';

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.bgWhite,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.borderSecondary),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (isPinned) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.sky50,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '공지',
                      style: AppTextStyle.labelSmallStyle.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
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
              ],
            ),
            const SizedBox(height: 8),
            Text(
              content,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyle.bodySmallStyle.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              dateText,
              style: AppTextStyle.labelSmallStyle.copyWith(
                color: AppColors.textTeritary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}