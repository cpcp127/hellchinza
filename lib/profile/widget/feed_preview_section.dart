import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:hellchinza/profile/widget/section_header.dart';

import '../../constants/app_colors.dart';
import '../../constants/app_text_style.dart';
import '../../feed/domain/feed_model.dart';
import 'feed_mini_card.dart';

class FeedPreviewSection extends StatelessWidget {
  const FeedPreviewSection({
    required this.title,
    required this.query,
    required this.onTapAll,
    required this.emptyText,
  });

  final String title;
  final Query<Map<String, dynamic>> query; // limit 포함해서 넘겨
  final VoidCallback onTapAll;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: title, onTapAll: onTapAll),
        const SizedBox(height: 10),

        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: query.snapshots(),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return Container();
            }
            if (!snap.hasData || snap.data!.docs.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(
                  emptyText,
                  style: AppTextStyle.bodySmallStyle.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              );
            }

            final docs = snap.data!.docs;

            return Column(
              children: docs.map((d) {
                final feed = FeedModel.fromJson(d.data());
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: FeedMiniCard(feed: feed),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }
}