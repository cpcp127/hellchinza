import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../common/common_back_appbar.dart';
import '../../../common/common_feed_card.dart';
import '../providers/feed_provider.dart';

class FeedDetailView extends ConsumerWidget {
  const FeedDetailView({super.key, required this.feedId});

  final String feedId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(feedDocProvider(feedId));

    return Scaffold(
      appBar: CommonBackAppbar(title: '피드'),
      body: async.when(
        loading: () => const Center(child: CupertinoActivityIndicator()),
        error: (e, _) => Center(child: Text('error: $e')),
        data: (feed) {
          if (feed == null) {
            return const Center(child: Text('피드가 없어요'));
          }
          return FeedCard(feedId: feedId);
        },
      ),
    );
  }
}
