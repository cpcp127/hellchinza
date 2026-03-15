import 'package:flutter/material.dart';
import 'package:hellchinza/profile/widget/section_header.dart';

import '../../constants/app_colors.dart';
import '../../constants/app_text_style.dart';
import '../../meet/domain/meet_model.dart';
import 'meet_mini_card.dart';

class MeetPreviewSection extends StatelessWidget {
  const MeetPreviewSection({
    super.key,
    required this.title,
    required this.items,
    required this.onTapAll,
    required this.emptyText,
  });

  final String title;
  final List<MeetModel> items;
  final VoidCallback? onTapAll;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: title,
          onTapAll: onTapAll ?? () {},
        ),
        const SizedBox(height: 10),
        if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Text(
              emptyText,
              style: AppTextStyle.bodySmallStyle.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          )
        else
          Column(
            children: items.map((meet) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: MeetMiniCard(meet: meet),
              );
            }).toList(),
          ),
      ],
    );
  }
}