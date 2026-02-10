import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hellchinza/common/common_feed_card.dart';

import '../../common/common_back_appbar.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_text_style.dart';
import '../domain/feed_model.dart';

final feedDocProvider =
FutureProvider.family<DocumentSnapshot<Map<String, dynamic>>, String>(
      (ref, feedId) async {
    return FirebaseFirestore.instance.collection('feeds').doc(feedId).get();
  },
);

class FeedDetailView extends ConsumerWidget {
  final String feedId;

  const FeedDetailView({super.key, required this.feedId});

  @override
  Widget build(BuildContext context,WidgetRef ref) {

    final asyncDoc = ref.watch(feedDocProvider(feedId));

    return Scaffold(
      appBar: CommonBackAppbar(title: '피드'),
      body: SingleChildScrollView(
        child: asyncDoc.when(
          loading: () => const Center(child: CupertinoActivityIndicator()),
          error: (e, _) => Center(child: Text('피드 로드 실패: $e')),
          data: (doc) {
            if (!doc.exists || doc.data() == null) {
              return Center(
                child: Text(
                  '피드가 없어요',
                  style: AppTextStyle.bodyMediumStyle.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              );
            }

            final feed = FeedModel.fromJson(doc.data()!);
            return FeedCard(feed: feed);
          },
        ),
      ),
    );
  }
}
