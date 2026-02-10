import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_pagination/firebase_pagination.dart';
import 'package:flutter/material.dart';

import '../../common/common_feed_card.dart';
import '../../constants/app_colors.dart';
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
