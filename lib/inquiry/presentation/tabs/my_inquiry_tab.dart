import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_pagination/firebase_pagination.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hellchinza/common/common_network_image.dart';
import 'package:hellchinza/constants/app_colors.dart';
import 'package:hellchinza/constants/app_text_style.dart';
import 'package:hellchinza/inquiry/presentation/inquiry_detail_view.dart';
import 'package:hellchinza/inquiry/providers/inquiry_provider.dart';

class MyInquiryTab extends ConsumerWidget {
  const MyInquiryTab({super.key, required this.uid});

  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = ref.read(inquiryRepoProvider).getMyInquiryQuery(uid);

    return FirestorePagination(
      query: query,
      limit: 10,
      isLive: false,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      onEmpty: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.support_agent_rounded,
              size: 42,
              color: AppColors.icDisabled,
            ),
            const SizedBox(height: 12),
            Text(
              '아직 문의가 없어요',
              style: AppTextStyle.titleSmallBoldStyle.copyWith(
                color: AppColors.textDefault,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '문의 작성 탭에서 궁금한 점을 남겨주세요 🙂',
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
        final data = (doc.data() as Map?)?.cast<String, dynamic>() ?? {};

        final message = (data['message'] ?? '').toString();
        final status = (data['status'] ?? 'open').toString();
        final imageUrls =
            (data['imageUrls'] as List?)?.map((e) => e.toString()).toList() ??
            [];

        DateTime? createdAt;
        final ts = data['createdAt'];
        if (ts is Timestamp) createdAt = ts.toDate();

        final dateText = createdAt == null
            ? ''
            : '${createdAt.year}.${createdAt.month.toString().padLeft(2, '0')}.${createdAt.day.toString().padLeft(2, '0')}';

        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => InquiryDetailView(
                    message: message,
                    status: status,
                    createdAt: createdAt,
                    imageUrls: imageUrls,
                    answer: data['answer']?.toString(),
                    answeredAt: (data['answeredAt'] is Timestamp)
                        ? (data['answeredAt'] as Timestamp).toDate()
                        : null,
                  ),
                ),
              );
            },
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
                      _InquiryStatusChip(status: status),
                      const Spacer(),
                      Text(
                        dateText,
                        style: AppTextStyle.labelSmallStyle.copyWith(
                          color: AppColors.textTeritary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      if (imageUrls.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: CommonNetworkImage(
                              imageUrl: imageUrls.first,
                              width: 50,
                              height: 50,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      Expanded(
                        child: Text(
                          message,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyle.bodyMediumStyle.copyWith(
                            color: AppColors.textDefault,
                          ),
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
  }
}

class _InquiryStatusChip extends StatelessWidget {
  const _InquiryStatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    late final String text;
    late final Color bg;
    late final Color fg;

    if (status == 'answered') {
      text = '답변완료';
      bg = AppColors.green10;
      fg = AppColors.green400;
    } else if (status == 'closed') {
      text = '종료';
      bg = AppColors.bgSecondary;
      fg = AppColors.textTeritary;
    } else {
      text = '접수됨';
      bg = AppColors.sky50;
      fg = AppColors.sky900;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: AppTextStyle.labelSmallStyle.copyWith(
          color: fg,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
