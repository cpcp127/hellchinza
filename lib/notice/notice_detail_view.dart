import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/app_text_style.dart';

class NoticeDetailView extends StatelessWidget {
  const NoticeDetailView({
    super.key,
    required this.title,
    required this.content,
    required this.createdAt,
  });

  final String title;
  final String content;
  final DateTime? createdAt;

  @override
  Widget build(BuildContext context) {
    final dateText = createdAt == null
        ? ''
        : '${createdAt!.year}.${createdAt!.month.toString().padLeft(2, '0')}.${createdAt!.day.toString().padLeft(2, '0')}';

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '공지사항',
          style: AppTextStyle.titleMediumBoldStyle,
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: AppTextStyle.headlineSmallBoldStyle,
            ),
            const SizedBox(height: 6),
            Text(
              dateText,
              style: AppTextStyle.labelSmallStyle.copyWith(
                color: AppColors.textTeritary,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: SingleChildScrollView(
                child: Text(
                  content,
                  style: AppTextStyle.bodyMediumStyle.copyWith(
                    color: AppColors.textDefault,
                    height: 1.5,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}