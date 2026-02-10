import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hellchinza/common/common_feed_card.dart';

import '../../common/common_back_appbar.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_text_style.dart';
import '../domain/feed_model.dart';

final feedDocProvider = FutureProvider.family<FeedModel?, String>((
  ref,
  feedId,
) async {
  final doc = await FirebaseFirestore.instance
      .collection('feeds')
      .doc(feedId)
      .get();
  if (!doc.exists) return null;
  return FeedModel.fromJson(doc.data()!);
});

class FeedDetailView extends ConsumerWidget {
  final String feedId;

  const FeedDetailView({super.key, required this.feedId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(feedDocProvider(feedId));

    return async.when(
      loading: () => const Center(child: CupertinoActivityIndicator()),
      error: (e, _) => Center(child: Text('error: $e')),
      data: (feed) {
        if (feed == null) return const Center(child: Text('피드가 없어요'));
        return FeedCard(feed: feed);
      },
    );
  }
}
