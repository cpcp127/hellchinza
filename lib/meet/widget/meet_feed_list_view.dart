import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_pagination/firebase_pagination.dart';
import 'package:flutter/material.dart';
import 'package:hellchinza/common/common_feed_card.dart';

import '../../constants/app_colors.dart';
import '../../constants/app_text_style.dart';
import '../../feed/domain/feed_model.dart';

class MeetFeedListView extends StatelessWidget {
  const MeetFeedListView({super.key, required this.meetId});

  final String meetId;

  Query<Map<String, dynamic>> _query() {
    return FirebaseFirestore.instance
        .collection('feeds')
        .where('meetId', isEqualTo: meetId)
        .orderBy('createdAt', descending: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgWhite,
      appBar: AppBar(
        backgroundColor: AppColors.bgWhite,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text('모임 피드'),
      ),
      body: FirestorePagination(
        query: _query(),
        limit: 12,
        isLive: true,

        initialLoader: const Center(
          child: Padding(
            padding: EdgeInsets.only(top: 24),
            child: CircularProgressIndicator(),
          ),
        ),
        bottomLoader: const Padding(
          padding: EdgeInsets.symmetric(vertical: 14),
          child: Center(child: CircularProgressIndicator()),
        ),
        onEmpty: Center(
          child: Text(
            '피드가 없어요',
            style: AppTextStyle.bodyMediumStyle.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),

        itemBuilder: (context, docs, index) {
          final doc = docs[index] as DocumentSnapshot<Map<String, dynamic>>;
          final data = doc.data()!;

          // ✅ 여기서 너의 "피드 공통 위젯"으로 렌더링하면 됨
          final feed = FeedModel.fromJson(data);
          return FeedCard(feed: feed);
        },
      ),
    );
  }
}
