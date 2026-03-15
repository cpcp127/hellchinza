import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hellchinza/meet/domain/meet_model.dart';

import '../../constants/app_colors.dart';
import '../../constants/app_text_style.dart';
import '../domain/meet_summary_model.dart';
import '../meet_list/meet_list_view.dart';
import 'meet_thumb.dart';

class MeetCard extends ConsumerWidget {
  const MeetCard({
    super.key,
    required this.item,
    required this.onTap,
  });

  final MeetModel item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final regionText = item.regions.isNotEmpty
        ? item.regions.first.fullName
        : '지역 미설정';

    final memberCountAsync = ref.watch(meetMemberCountProvider(item.id));

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.bgWhite,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.borderSecondary),
        ),
        child: Row(
          children: [
            MeetThumb(url: item.imageUrls),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.sky50,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: AppColors.borderPrimary),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        child: Text(
                          item.category,
                          style: AppTextStyle.labelXSmallStyle.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyle.titleMediumBoldStyle.copyWith(
                        color: AppColors.textDefault,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(
                          Icons.people_alt_outlined,
                          size: 16,
                          color: AppColors.icSecondary,
                        ),
                        const SizedBox(width: 6),
                        memberCountAsync.when(
                          data: (count) => Text(
                            '현재 $count/${item.maxMembers}명',
                            style: AppTextStyle.labelSmallStyle.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                          loading: () => Text(
                            '현재 -/${item.maxMembers}명',
                            style: AppTextStyle.labelSmallStyle.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                          error: (_, __) => Text(
                            '현재 -/${item.maxMembers}명',
                            style: AppTextStyle.labelSmallStyle.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.place_outlined,
                          size: 16,
                          color: AppColors.icSecondary,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            regionText,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyle.labelSmallStyle.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatKoreanDateTime(DateTime dt) {
    final mm = dt.month.toString();
    final dd = dt.day.toString();
    final hh = dt.hour;
    final mi = dt.minute.toString().padLeft(2, '0');
    final isAm = hh < 12;
    final h12 = hh == 0 ? 12 : (hh > 12 ? hh - 12 : hh);
    final ap = isAm ? '오전' : '오후';
    return '$mm/$dd $ap $h12:$mi';
  }
}