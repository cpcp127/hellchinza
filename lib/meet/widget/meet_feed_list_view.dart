import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_pagination/firebase_pagination.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hellchinza/common/common_feed_card.dart';

import '../../constants/app_colors.dart';
import '../../constants/app_text_style.dart';
import '../../feed/create_feed/create_feed_view.dart';
import '../../feed/domain/feed_model.dart';
import '../../workout_goal/provider/workout_goal_provider.dart';
import '../meet_detail/meat_detail_view.dart';

class MeetFeedListView extends ConsumerStatefulWidget {
  const MeetFeedListView({super.key, required this.meetId});

  final String meetId;

  @override
  ConsumerState<MeetFeedListView> createState() => _MeetFeedListViewState();
}

class _MeetFeedListViewState extends ConsumerState<MeetFeedListView> {
  static const int _pageSize = 12;

  final _scrollCtrl = ScrollController();

  final List<DocumentSnapshot<Map<String, dynamic>>> _docs = [];
  DocumentSnapshot<Map<String, dynamic>>? _lastDoc;

  bool _initialLoading = false;
  bool _pagingLoading = false;
  bool _hasMore = true;

  int _refreshTick = 0;
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
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollCtrl.hasClients) return;
    if (_pagingLoading || _initialLoading || !_hasMore) return;

    final pos = _scrollCtrl.position;
    if (pos.pixels >= pos.maxScrollExtent - 250) {
      _fetchNext();
    }
  }

  String _makeQueryKey() => '${widget.meetId}_$_refreshTick';

  Query<Map<String, dynamic>> _buildQuery() {
    return FirebaseFirestore.instance
        .collection('feeds')
        .where('meetId', isEqualTo: widget.meetId)
        .orderBy('createdAt', descending: true);
  }

  void _triggerRefresh() {
    _refreshTick++;
    final newKey = _makeQueryKey();
    if (_queryKey != newKey) {
      _queryKey = newKey;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _resetAndFetch();
      });
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
    } catch (_) {
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
    } catch (_) {
      if (!mounted) return;
      setState(() => _pagingLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // ✅ MeetListView 패턴 유지 (여기선 refreshTick만)
    final newKey = _makeQueryKey();
    if (_queryKey != newKey) {
      _queryKey = newKey;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _resetAndFetch();
      });
    }

    return Scaffold(
      backgroundColor: AppColors.bgWhite,
      appBar: AppBar(
        backgroundColor: AppColors.bgWhite,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text('모임 피드'),
        // ✅ actions에 + 버튼 없음
      ),
      body: RefreshIndicator(
        color: AppColors.sky400,
        backgroundColor: AppColors.bgWhite,
        onRefresh: () async {
          _triggerRefresh();
          await Future.delayed(const Duration(milliseconds: 250));
        },
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    // ✅ 처음 로딩
    if (_initialLoading) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        children: const [
          SizedBox(height: 24),
          Center(child: CircularProgressIndicator()),
        ],
      );
    }

    // ✅ empty (너가 준 패턴 적용)
    if (_docs.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 60, 16, 16),
        children: [
          Text(
            '피드가 없어요',
            style: AppTextStyle.headlineSmallBoldStyle.copyWith(
              color: AppColors.textDefault,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Text(
            '모임 활동을 기록해서 피드를 만들어 볼까요?',
            style: AppTextStyle.bodyMediumStyle.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CreateFeedView(meetId: widget.meetId),
                  ),
                );
                ref.invalidate(meetPhotoFeedSectionProvider(widget.meetId));
                ref
                    .read(workoutGoalControllerProvider.notifier)
                    .init(uid: FirebaseAuth.instance.currentUser!.uid);
                _triggerRefresh();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.btnPrimary,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                '피드 만들기',
                style: AppTextStyle.titleMediumBoldStyle.copyWith(
                  color: AppColors.white,
                ),
              ),
            ),
          ),
        ],
      );
    }

    // ✅ list
    return ListView.builder(
      controller: _scrollCtrl,
      physics: const AlwaysScrollableScrollPhysics(),

      itemCount: _docs.length + 1,
      itemBuilder: (context, index) {
        if (index == _docs.length) {
          if (!_hasMore) return const SizedBox(height: 12);
          if (!_pagingLoading) return const SizedBox(height: 12);
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final doc = _docs[index];
        final data = doc.data();
        if (data == null) return const SizedBox.shrink();

        final feed = FeedModel.fromJson(data);
        return FeedCard(feedId: feed.id);
      },
    );
  }
}
