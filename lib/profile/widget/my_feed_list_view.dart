import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_pagination/firebase_pagination.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../common/common_feed_card.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_text_style.dart';
import '../../feed/domain/feed_model.dart';

class MyFeedsListView extends ConsumerStatefulWidget {
  const MyFeedsListView({
    super.key,
    required this.title,
    required this.query,
  });

  final String title;
  final Query<Map<String, dynamic>> query;

  @override
  ConsumerState<MyFeedsListView> createState() => _MyFeedsListViewState();
}

class _MyFeedsListViewState extends ConsumerState<MyFeedsListView> {
  static const int _pageSize = 10;

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

  String _makeQueryKey() => '${widget.query.hashCode}_$_refreshTick';

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
      final snap = await widget.query.limit(_pageSize).get();
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
      final snap = await widget.query
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

  void _triggerRefresh() {
    setState(() {
      _refreshTick++;
    });
    // 실제 리셋은 queryKey 감지로 통일
  }

  @override
  Widget build(BuildContext context) {
    // ✅ queryKey 변화 감지 → 리셋
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
        title: Text(widget.title),
        backgroundColor: AppColors.bgWhite,
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
    // ✅ 초기 로딩
    if (_initialLoading) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
        children: const [
          Center(child: CircularProgressIndicator()),
        ],
      );
    }

    // ✅ empty (기존 UI 유지)
    if (_docs.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 60, 16, 16),
        children: [
          Center(
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
        ],
      );
    }

    // ✅ list (separator 12 유지)
    return ListView.separated(
      controller: _scrollCtrl,
      physics: const AlwaysScrollableScrollPhysics(),

      itemCount: _docs.length + 1,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
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