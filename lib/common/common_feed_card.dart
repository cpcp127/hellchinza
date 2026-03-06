import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_pagination/firebase_pagination.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hellchinza/common/common_back_appbar.dart';
import 'package:hellchinza/common/common_place_widget.dart';
import 'package:hellchinza/services/feed_service.dart';

import '../auth/domain/user_mini_provider.dart';
import '../auth/presentation/auth_controller.dart';
import '../claim/claim_view.dart';
import '../claim/domain/claim_model.dart';
import '../constants/app_colors.dart';
import '../constants/app_text_style.dart';
import '../feed/create_feed/create_feed_state.dart';
import '../feed/create_feed/create_feed_view.dart';
import '../feed/domain/feed_model.dart';
import '../feed/domain/poll_model.dart';
import '../feed/feed_detail/feed_detail_view.dart';
import '../feed/feed_list/feed_list_controller.dart';
import '../meet/meet_detail/meat_detail_view.dart';
import '../profile/widget/feed_type_pill.dart';
import '../services/dialog_service.dart';
import '../services/snackbar_service.dart';
import '../utils/date_time_util.dart';
import '../workout_goal/provider/workout_goal_provider.dart';
import 'common_action_sheet.dart';
import 'common_context_menu.dart';
import 'common_like_user_sheet.dart';
import 'common_network_image.dart';
import 'common_profile_avatar.dart';
import 'common_text_field.dart';

class FeedCard extends ConsumerWidget {
  final String feedId;

  const FeedCard({super.key, required this.feedId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncFeed = ref.watch(feedDocProvider(feedId));

    return asyncFeed.when(
      loading: () => Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.bgWhite,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const SizedBox(
          height: 140,
          child: Center(child: CupertinoActivityIndicator()),
        ),
      ),
      error: (e, _) => const SizedBox.shrink(),
      data: (feed) {
        if (feed == null) return const SizedBox.shrink();
        return _FeedCardBody(feed: feed);
      },
    );
  }
}

class _FeedCardBody extends StatelessWidget {
  final FeedModel feed;

  const _FeedCardBody({required this.feed});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.bgWhite,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _AuthorSection(authorUid: feed.authorUid, feed: feed),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                FeedTypePill(mainType: feed.mainType),
                if (feed.subType != null) ...[
                  const SizedBox(width: 6),
                  Text(
                    feed.subType!,
                    style: AppTextStyle.labelSmallStyle.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (feed.imageUrls?.isNotEmpty == true) ...[
            const SizedBox(height: 12),
            _FeedImagePager(imageUrls: feed.imageUrls!),
          ],
          if (feed.contents?.isNotEmpty == true) ...[
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Text(feed.contents!, style: AppTextStyle.bodyMediumStyle),
            ),
          ],
          if (feed.poll != null) ...[
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: PollSection(poll: feed.poll!, feedId: feed.id),
            ),
          ],
          if (feed.place != null) ...[
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: CommonPlaceWidget(
                title: feed.place!.title,
                address: feed.place!.address,
                lat: feed.place!.lat,
                lng: feed.place!.lng,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              '${DateTimeUtil.formatRelative(feed.createdAt)}',
              style: AppTextStyle.labelSmallStyle.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: _FeedActionRow(feed: feed),
          ),
        ],
      ),
    );
  }
}

class FeedAuthorRow extends ConsumerWidget {
  const FeedAuthorRow({super.key, required this.authorUid});

  final String authorUid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncMini = ref.watch(userMiniProvider(authorUid));

    return asyncMini.when(
      loading: () => Center(child: CupertinoActivityIndicator()),
      error: (e, _) => Text(
        '작성자 불러오기 실패',
        style: AppTextStyle.bodySmallStyle.copyWith(
          color: AppColors.textSecondary,
        ),
      ),
      data: (mini) {
        final nickname = mini?.nickname.isNotEmpty == true
            ? mini!.nickname
            : '';
        final photoUrl = mini?.photoUrl;

        return Row(
          children: [
            CommonProfileAvatar(
              imageUrl: photoUrl,
              size: 40,
              uid: mini!.uid,
              gender: mini.gender,
            ),
            const SizedBox(width: 8),
            Text(
              nickname,
              style: AppTextStyle.titleSmallBoldStyle.copyWith(
                color: AppColors.textDefault,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _AuthorSection extends ConsumerWidget {
  final String authorUid;
  final FeedModel feed;

  const _AuthorSection({required this.authorUid, required this.feed});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          FeedAuthorRow(authorUid: authorUid),
          const Spacer(),
          IconButton(
            icon: const Icon(
              Icons.more_horiz,
              color: AppColors.icSecondary,
              size: 22,
            ),
            onPressed: () async {
              final myUid = FirebaseAuth.instance.currentUser?.uid;
              final isMine = myUid != null && myUid == authorUid;

              await FeedService().showFeedMoreActionSheet(
                context: context,
                isMine: isMine,
                onEdit: isMine
                    ? () async {
                        await Navigator.push(
                          context,
                          CupertinoPageRoute(
                            fullscreenDialog: true,
                            builder: (context) {
                              return CreateFeedView(mode: 'update', feed: feed);
                            },
                          ),
                        );
                        ref.invalidate(feedDocProvider(feed.id));
                        if (feed.mainType == '오운완') {
                          ref
                              .read(workoutGoalControllerProvider.notifier)
                              .init();
                        }
                        if (feed.meetId == null) {
                          ref
                              .read(feedListControllerProvider.notifier)
                              .refresh();
                        } else {
                          ref.invalidate(
                            meetPhotoFeedSectionProvider(feed.meetId!),
                          );
                        }
                      }
                    : null,
                onDelete: isMine
                    ? () async {
                        await FeedService().deleteFeed(feedId: feed.id);
                        if (feed.mainType == '오운완') {
                          ref
                              .read(workoutGoalControllerProvider.notifier)
                              .init();
                        }
                        if (feed.meetId == null) {
                          ref
                              .read(feedListControllerProvider.notifier)
                              .refresh();
                        } else {
                          ref.invalidate(
                            meetPhotoFeedSectionProvider(feed.meetId!),
                          );
                        }
                      }
                    : null,
                onReport: !isMine
                    ? () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ClaimView(
                              target: ClaimTarget(
                                type: ClaimTargetType.feed,
                                targetId: feed.id,
                                targetOwnerUid: feed.authorUid,
                                title: feed.contents ?? '피드',
                                imageUrl: feed.imageUrls?.isNotEmpty == true
                                    ? feed.imageUrls!.first
                                    : null,
                              ),
                            ),
                          ),
                        );
                      }
                    : null,
              );
            },
          ),
        ],
      ),
    );
  }
}

class _FeedImagePager extends StatefulWidget {
  final List<String> imageUrls;

  const _FeedImagePager({super.key, required this.imageUrls});

  @override
  State<_FeedImagePager> createState() => _FeedImagePagerState();
}

class _FeedImagePagerState extends State<_FeedImagePager> {
  int currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: Stack(
        children: [
          // 🔹 이미지 PageView
          PageView.builder(
            itemCount: widget.imageUrls.length,
            onPageChanged: (index) {
              setState(() => currentIndex = index);
            },
            itemBuilder: (context, index) {
              return CommonNetworkImage(
                imageUrl: widget.imageUrls[index],
                fit: BoxFit.cover,
              );
            },
          ),

          // 🔹 이미지 개수 표시 (여러 장일 때만)
          if (widget.imageUrls.length > 1)
            Positioned(
              top: 10,
              right: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.55),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${currentIndex + 1} / ${widget.imageUrls.length}',
                  style: AppTextStyle.labelSmallStyle.copyWith(
                    color: AppColors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class PollSection extends ConsumerWidget {
  final PollModel poll;
  final String feedId;

  const PollSection({super.key, required this.poll, required this.feedId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myUid = FirebaseAuth.instance.currentUser!.uid;

    // 내가 투표한 옵션 id (없으면 null)
    final String? myVotedOptionId = _findMyVotedOptionId(poll, myUid);

    final totalVotes = poll.options.fold<int>(
      0,
      (sum, o) => sum + o.voterUids.length,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: poll.options.map((option) {
        final count = option.voterUids.length;
        final percent = totalVotes == 0 ? 0.0 : count / totalVotes;

        final bool isMyVote = option.voterUids.contains(myUid);
        final bool hasVoted = myVotedOptionId != null;

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: GestureDetector(
            onTap: () async {
              await _handleVoteTap(
                context: context,
                option: option,
                myVotedOptionId: myVotedOptionId,
              );
              ref.invalidate(feedDocProvider(feedId));
            },
            behavior: HitTestBehavior.translucent,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isMyVote
                      ? AppColors.borderPrimary
                      : AppColors.borderSecondary,
                ),
                color: isMyVote ? AppColors.sky50 : AppColors.bgWhite,
              ),
              child: Stack(
                children: [
                  SizedBox(
                    height: 36,
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            option.text,
                            style: AppTextStyle.labelMediumStyle.copyWith(
                              color: isMyVote
                                  ? AppColors.textPrimary
                                  : AppColors.textDefault,
                            ),
                          ),
                        ),
                        Text(
                          '$count',
                          style: AppTextStyle.labelSmallStyle.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ───────────────────────── helpers ─────────────────────────

  String? _findMyVotedOptionId(PollModel poll, String myUid) {
    for (final o in poll.options) {
      if (o.voterUids.contains(myUid)) {
        return o.id;
      }
    }
    return null;
  }

  Future<void> _handleVoteTap({
    required BuildContext context,
    required PollOptionModel option,
    required String? myVotedOptionId,
  }) async {
    // 이미 같은 옵션에 투표한 경우 → 아무 동작 X
    if (myVotedOptionId == option.id) {
      return;
    }

    // 아직 투표 안 한 경우
    if (myVotedOptionId == null) {
      final ok = await _showConfirmDialog(
        context,
        title: '투표하시겠어요?',
        message: '"${option.text}"로 투표합니다.',
      );
      if (ok) {
        await FeedService().vote(feedId: feedId, newOptionId: option.id);
      }
      return;
    }

    // 투표 변경
    final ok = await _showConfirmDialog(
      context,
      title: '투표를 변경할까요?',
      message: '"${option.text}"로 변경합니다.',
    );
    if (ok) {
      await FeedService().vote(feedId: feedId, newOptionId: option.id);
    }
  }

  Future<bool> _showConfirmDialog(
    BuildContext context, {
    required String title,
    required String message,
  }) async {
    final result = await DialogService.showConfirm(
      context: context,
      title: title,
      message: message,
      confirmText: '확인',
      isDestructive: false,
    );

    return result ?? false;
  }
}

class _FeedActionRow extends ConsumerWidget {
  final FeedModel feed;

  const _FeedActionRow({required this.feed});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    final isLiked = feed.likeUids.contains(myUid);
    return Row(
      children: [
        Row(
          children: [
            GestureDetector(
              onTap: () async {
                await const FeedService().toggleLike(
                  feedId: feed.id,
                  myUid: myUid ?? '',
                );

                ref.invalidate(feedDocProvider(feed.id));
              },
              child: Icon(
                isLiked ? Icons.favorite : Icons.favorite_border,
                size: 24,
                color: isLiked ? AppColors.red100 : AppColors.icSecondary,
              ),
            ),
            const SizedBox(width: 6),
            GestureDetector(
              onTap: () {
                LikeUserBottomSheet.show(
                  context: context,
                  likeUids: feed.likeUids,
                );
              },
              child: Text(
                '${feed.likeUids.length}',
                style: AppTextStyle.labelMediumStyle.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(width: 16),
        GestureDetector(
          onTap: () {
            showFeedCommentBottomSheet(context: context, feedId: feed.id);
          },
          child: _ActionItem(
            icon: Icons.chat_bubble_outline,
            label: feed.commentCount.toString(),
          ),
        ),
      ],
    );
  }

  Future<void> showFeedCommentBottomSheet({
    required BuildContext context,
    required String feedId,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      builder: (_) => FeedCommentBottomSheet(feedId: feedId),
    );
  }
}

class _ActionItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? iconColor;

  const _ActionItem({required this.icon, required this.label, this.iconColor});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 24, color: iconColor ?? AppColors.icSecondary),
        const SizedBox(width: 6),
        Text(
          label,
          style: AppTextStyle.labelMediumStyle.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class FeedCommentBottomSheet extends ConsumerStatefulWidget {
  final String feedId;

  const FeedCommentBottomSheet({super.key, required this.feedId});

  @override
  ConsumerState<FeedCommentBottomSheet> createState() =>
      _FeedCommentBottomSheetState();
}

class _FeedCommentBottomSheetState
    extends ConsumerState<FeedCommentBottomSheet> {
  final TextEditingController _controller = TextEditingController();

  // ✅ FirestorePagination key 대체용
  int valueKey = 0;

  bool isEnabled = false;

  // ✅ 수동 페이징 상태
  static const int _pageSize = 20;
  final _scrollCtrl = ScrollController();

  final List<DocumentSnapshot<Map<String, dynamic>>> _docs = [];
  DocumentSnapshot<Map<String, dynamic>>? _lastDoc;

  bool _initialLoading = false;
  bool _pagingLoading = false;
  bool _hasMore = true;

  String _queryKey = '';

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _queryKey = _makeQueryKey();
      _resetAndFetch();
    });
  }

  @override
  void dispose() {
    _scrollCtrl.removeListener(_onScroll);
    _scrollCtrl.dispose();
    _controller.dispose();
    super.dispose();
  }

  // -------------------------
  // Query / Key
  // -------------------------
  Query<Map<String, dynamic>> _buildQuery() {
    return FirebaseFirestore.instance
        .collection('feeds')
        .doc(widget.feedId)
        .collection('comments')
        .orderBy('createdAt', descending: true);
  }

  String _makeQueryKey() => '${widget.feedId}_$valueKey';

  // -------------------------
  // Paging
  // -------------------------
  void _onScroll() {
    if (!_scrollCtrl.hasClients) return;
    if (_pagingLoading || _initialLoading || !_hasMore) return;

    final pos = _scrollCtrl.position;
    if (pos.pixels >= pos.maxScrollExtent - 250) {
      _fetchNext();
    }
  }

  Future<void> _resetAndFetch() async {
    if (_initialLoading) return;

    setState(() {
      _docs.clear();
      _lastDoc = null;
      _hasMore = true;
      _initialLoading = true;
      _pagingLoading = false;
    });

    try {
      final snap = await _buildQuery().limit(_pageSize).get();
      final newDocs = snap.docs;

      if (!mounted) return;
      setState(() {
        _docs.addAll(newDocs);
        _lastDoc = newDocs.isNotEmpty ? newDocs.last : null;
        _hasMore = newDocs.length == _pageSize;
        _initialLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _initialLoading = false);
    }
  }

  Future<void> _fetchNext() async {
    if (!_hasMore) return;
    if (_lastDoc == null) return;
    if (_pagingLoading) return;

    setState(() => _pagingLoading = true);

    try {
      final snap = await _buildQuery()
          .startAfterDocument(_lastDoc!)
          .limit(_pageSize)
          .get();

      final newDocs = snap.docs;

      if (!mounted) return;
      setState(() {
        _docs.addAll(newDocs);
        _lastDoc = newDocs.isNotEmpty ? newDocs.last : _lastDoc;
        _hasMore = newDocs.length == _pageSize;
        _pagingLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _pagingLoading = false);
    }
  }

  void _triggerRefresh() {
    setState(() {
      valueKey++; // ✅ queryKey 변화 유도
    });
    // 실제 리셋은 build에서 queryKey 감지로 통일
  }

  // -------------------------
  // UI
  // -------------------------
  @override
  Widget build(BuildContext context) {
    // ✅ 핵심: valueKey(=queryKey)가 바뀌면 리셋
    final newKey = _makeQueryKey();
    if (_queryKey != newKey) {
      _queryKey = newKey;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _resetAndFetch();
      });
    }

    return Scaffold(
      appBar: const CommonCloseAppbar(
        title: '댓글',
        backgroundColor: Colors.transparent,
      ),
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(child: feedCommentList()),
            const Divider(height: 1),
            commentInput(),
          ],
        ),
      ),
    );
  }

  Widget feedCommentList() {
    // ✅ 초기 로딩
    if (_initialLoading) {
      return const Center(child: CupertinoActivityIndicator());
    }

    // ✅ 비어있을 때
    if (_docs.isEmpty) {
      return Center(
        child: Text(
          '첫 댓글을 남겨보세요',
          style: AppTextStyle.bodyMediumStyle.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      );
    }

    // ✅ list + separator(12) + bottom loader
    return ListView.separated(
      controller: _scrollCtrl,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: _docs.length + 1,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        if (index == _docs.length) {
          if (!_hasMore) return const SizedBox(height: 16);
          if (!_pagingLoading) return const SizedBox(height: 16);

          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CupertinoActivityIndicator()),
          );
        }

        final doc = _docs[index];
        final data = doc.data();
        if (data == null) return const SizedBox.shrink();

        // commentId가 문서 id일 수 있으니 보정(없으면 doc.id 사용)
        data['id'] ??= doc.id;

        return feedCommentItem(data);
      },
    );
  }

  Widget feedCommentItem(Map<String, dynamic> data) {
    Offset? _tapPosition;
    final myUid = FirebaseAuth.instance.currentUser!.uid;
    final isMine = data['authorUid'] == myUid;
    final timeText = DateTimeUtil.from(data['createdAt']);
    final asyncMini = ref.watch(userMiniProvider(data['authorUid']));

    return asyncMini.when(
      data: (mini) {
        if (mini == null) return const SizedBox.shrink();

        return GestureDetector(
          onTapDown: (d) => _tapPosition = d.globalPosition,
          onLongPress: () {
            if (_tapPosition == null) return;
            HapticFeedback.mediumImpact();

            final items = isMine
                ? [
                    CommonContextMenuItem(
                      icon: Icons.delete_outline,
                      label: '삭제하기',
                      isDestructive: true,
                      onTap: () async {
                        try {
                          await const FeedService().deleteComment(
                            feedId: widget.feedId,
                            commentId: data['id'],
                            valueKey: valueKey,
                          );

                          // ✅ 삭제 즉시 반영 (실시간X)
                          _triggerRefresh();

                          SnackbarService.show(
                            type: AppSnackType.success,
                            message: '댓글이 삭제되었습니다',
                          );
                        } catch (e, st) {
                          debugPrint('deleteComment error: $e\n$st');
                          SnackbarService.show(
                            type: AppSnackType.error,
                            message: '댓글 삭제에 실패했습니다',
                          );
                        }
                      },
                    ),
                  ]
                : [
                    CommonContextMenuItem(
                      icon: Icons.flag_outlined,
                      label: '신고하기',
                      isDestructive: true,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ClaimView(
                              target: ClaimTarget(
                                type: ClaimTargetType.comment,
                                targetId: data['id'],
                                targetOwnerUid: data['authorNickname'],
                                title: data['content'] ?? '피드',
                                parentId: data['authorId'],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ];

            CommonContextMenu.show(
              context: context,
              position: _tapPosition!,
              items: items,
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              color: Colors.white,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CommonProfileAvatar(
                    imageUrl: mini.photoUrl,
                    size: 40,
                    uid: data['authorUid'],
                    gender: mini.gender,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              mini.nickname ?? '',
                              style: AppTextStyle.labelMediumStyle,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              timeText,
                              style: AppTextStyle.labelSmallStyle.copyWith(
                                color: AppColors.textTeritary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          data['content'] ?? '',
                          style: AppTextStyle.bodyMediumStyle,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
      loading: () => const Center(child: CupertinoActivityIndicator()),
      error: (e, _) => Text(
        '작성자 불러오기 실패',
        style: AppTextStyle.bodySmallStyle.copyWith(
          color: AppColors.textSecondary,
        ),
      ),
    );
  }

  Widget commentInput() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Row(
          children: [
            Expanded(
              child: CommonTextField(
                controller: _controller,
                onChanged: (_) {
                  setState(() {
                    isEnabled = _controller.text.trim().isNotEmpty;
                  });
                },
                hintText: '댓글을 입력하세요',
                maxLines: 1,
                minLines: 1,
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () {
                if (!isEnabled) return;
                _submitComment();
              },
              child: Container(
                width: 44,
                height: 44,
                color: Colors.transparent,
                alignment: Alignment.center,
                child: Icon(
                  Icons.send,
                  size: 20,
                  color: isEnabled ? AppColors.sky400 : AppColors.bgSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitComment() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    try {
      await const FeedService().addComment(
        feedId: widget.feedId,
        content: text,
      );

      FocusManager.instance.primaryFocus?.unfocus();
      _controller.clear();

      setState(() {
        isEnabled = false;
      });

      // ✅ 작성 즉시 리스트 갱신 (실시간X, 수동 refresh)
      _triggerRefresh();

      // commentCount 증가 + feed invalidate는 기존 그대로
      await FirebaseFirestore.instance.runTransaction((tx) async {
        final feedRef = FirebaseFirestore.instance
            .collection('feeds')
            .doc(widget.feedId);
        tx.update(feedRef, {'commentCount': FieldValue.increment(1)});
      });

      ref.invalidate(feedDocProvider(widget.feedId));
    } catch (e) {
      debugPrint('addComment error: $e');
    }
  }
}
