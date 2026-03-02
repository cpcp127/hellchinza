import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_pagination/firebase_pagination.dart';
import 'package:flutter/material.dart';

import '../../common/common_feed_card.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_text_style.dart';
import '../../feed/domain/feed_model.dart';

class MyFeedsListView extends StatelessWidget {
  const MyFeedsListView({
    super.key,
    required this.title,
    required this.query,
  });

  final String title;
  final Query<Map<String, dynamic>> query;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgWhite,
      appBar: AppBar(
        title: Text(title),
        backgroundColor: AppColors.bgWhite,
      ),
      body: FirestorePagination(
        query: query,
        limit: 10,
          onEmpty: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.feed_outlined,
                  size: 42,
                  color: AppColors.icDisabled,
                ),
                const SizedBox(height: 12),
                Text(
                  '아직 피드가 없어요',
                  style: AppTextStyle.titleSmallBoldStyle.copyWith(
                    color: AppColors.textDefault,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '아직 모임 피드가 없어요.\n첫 피드를 작성해보세요 ✍️',
                  textAlign: TextAlign.center,
                  style: AppTextStyle.bodySmallStyle.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          separatorBuilder: (context, index) =>
          const SizedBox(height: 12),

          itemBuilder: (context, docs, index) {

            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;

            final feed = FeedModel.fromJson(data);
            return FeedCard(feed: feed);
          }
      ),
    );
  }
}
