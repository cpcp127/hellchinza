import 'package:flutter/material.dart';

import '../common/common_network_image.dart';
import '../constants/app_colors.dart';
import '../constants/app_text_style.dart';

class InquiryDetailView extends StatelessWidget {
  const InquiryDetailView({
    super.key,
    required this.message,
    required this.status,
    required this.createdAt,
    required this.answer,
    required this.answeredAt, required this.imageUrls,
  });

  final String message;
  final String status;
  final DateTime? createdAt;
  final String? answer;
  final DateTime? answeredAt;
  final List<String> imageUrls;
  @override
  Widget build(BuildContext context) {
    final dateText = createdAt == null
        ? ''
        : '${createdAt!.year}.${createdAt!.month.toString().padLeft(2, '0')}.${createdAt!.day.toString().padLeft(2, '0')}';

    final answeredText = answeredAt == null
        ? null
        : '${answeredAt!.year}.${answeredAt!.month.toString().padLeft(2, '0')}.${answeredAt!.day.toString().padLeft(2, '0')}';

    return Scaffold(
      backgroundColor: AppColors.bgWhite,
      appBar: AppBar(
        title: Text('문의 상세', style: AppTextStyle.titleMediumBoldStyle),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [

                Text(
                  dateText,
                  style: AppTextStyle.labelSmallStyle.copyWith(
                    color: AppColors.textTeritary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            imageUrls.isNotEmpty? ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: CommonNetworkImage(
                imageUrl: imageUrls.first,
                width: 200,
                height: 200,
                fit: BoxFit.cover,
              ),
            ):Container(),
            const SizedBox(height: 18),
            Text(
              message,
              style: AppTextStyle.bodyMediumStyle.copyWith(
                color: AppColors.textDefault,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 18),

            if (answer != null && answer!.isNotEmpty) ...[
              Container(
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
                    Text(
                      '답변',
                      style: AppTextStyle.titleSmallBoldStyle.copyWith(
                        color: AppColors.textDefault,
                      ),
                    ),
                    if (answeredText != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        answeredText!,
                        style: AppTextStyle.labelSmallStyle.copyWith(
                          color: AppColors.textTeritary,
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Text(
                      answer!,
                      style: AppTextStyle.bodyMediumStyle.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              Text(
                '아직 답변이 없어요. 확인 후 답변드릴게요 🙂',
                style: AppTextStyle.bodySmallStyle.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}