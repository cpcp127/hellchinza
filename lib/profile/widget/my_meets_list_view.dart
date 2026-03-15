import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../constants/app_colors.dart';
import '../../constants/app_text_style.dart';
import '../../meet/meet_detail/meat_detail_view.dart';
import '../../meet/domain/meet_model.dart';
import '../../meet/widget/meet_card.dart';

class MyMeetsListView extends ConsumerStatefulWidget {
  const MyMeetsListView({
    super.key,
    required this.title,
    required this.items,
  });

  final String title;
  final List<MeetModel> items;

  @override
  ConsumerState<MyMeetsListView> createState() => _MyMeetsListViewState();
}

class _MyMeetsListViewState extends ConsumerState<MyMeetsListView> {
  static const int _pageSize = 10;

  final _scrollCtrl = ScrollController();

  final List<MeetModel> _visibleItems = [];

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

  String _makeQueryKey() {
    return '${widget.items.hashCode}_$_refreshTick';
  }

  Future<void> _resetAndFetch() async {
    if (_initialLoading) return;

    setState(() {
      _visibleItems.clear();
      _hasMore = true;
      _initialLoading = true;
      _pagingLoading = false;
    });

    try {
      final newItems = widget.items.take(_pageSize).toList();

      if (!mounted) return;
      setState(() {
        _visibleItems.addAll(newItems);
        _hasMore = widget.items.length > _visibleItems.length;
        _initialLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _initialLoading = false);
    }
  }

  Future<void> _fetchNext() async {
    if (!_hasMore || _pagingLoading) return;

    setState(() => _pagingLoading = true);

    try {
      final start = _visibleItems.length;
      final end = (start + _pageSize).clamp(0, widget.items.length);
      final newItems = widget.items.sublist(start, end);

      if (!mounted) return;
      setState(() {
        _visibleItems.addAll(newItems);
        _hasMore = widget.items.length > _visibleItems.length;
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
  }

  @override
  Widget build(BuildContext context) {
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
        title: Text(widget.title, style: AppTextStyle.titleMediumBoldStyle),
        backgroundColor: AppColors.bgWhite,
      ),
      body: RefreshIndicator(
        color: AppColors.sky400,
        backgroundColor: AppColors.bgWhite,
        onRefresh: () async {
          _triggerRefresh();
          await Future.delayed(const Duration(milliseconds: 250));
        },
        child: _buildBody(context),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_initialLoading) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
        children: const [
          Center(child: CircularProgressIndicator()),
        ],
      );
    }

    if (_visibleItems.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 60, 16, 16),
        children: [
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.people_rounded,
                  size: 42,
                  color: AppColors.icDisabled,
                ),
                const SizedBox(height: 12),
                Text(
                  '아직 모임이 없어요',
                  style: AppTextStyle.titleSmallBoldStyle.copyWith(
                    color: AppColors.textDefault,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '운동친구를 만나는 첫 모임에 참가,생성 해볼까요?',
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

    return ListView.builder(
      controller: _scrollCtrl,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(top: 12, bottom: 16),
      itemCount: _visibleItems.length + 1,
      itemBuilder: (context, index) {
        if (index == _visibleItems.length) {
          if (!_hasMore) return const SizedBox(height: 12);
          if (!_pagingLoading) return const SizedBox(height: 12);
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final item = _visibleItems[index];

        return Padding(
          padding: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
          child: MeetCard(
            item: item,
            onTap: () {
              Navigator.push(
                context,
                CupertinoPageRoute(
                  fullscreenDialog: true,
                  builder: (context) {
                    return MeetDetailView(meetId: item.id);
                  },
                ),
              );
            },
          ),
        );
      },
    );
  }
}