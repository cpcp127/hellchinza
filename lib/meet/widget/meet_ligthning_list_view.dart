import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_pagination/firebase_pagination.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../constants/app_colors.dart';
import '../../constants/app_text_style.dart';
import '../../services/snackbar_service.dart';
import '../domain/lightning_model.dart';
import '../lightning_create/lightning_create_view.dart';
import '../meet_detail/meat_detail_view.dart';
import 'lightning_card.dart';

class MeetLightningListView extends ConsumerStatefulWidget {
  const MeetLightningListView({super.key, required this.meetId});

  final String meetId;

  @override
  ConsumerState<MeetLightningListView> createState() =>
      _MeetLightningListViewState();
}

class _MeetLightningListViewState extends ConsumerState<MeetLightningListView> {
  static const int _pageSize = 10;

  final _scrollCtrl = ScrollController();

  final List<DocumentSnapshot<Map<String, dynamic>>> _docs = [];
  DocumentSnapshot<Map<String, dynamic>>? _lastDoc;

  bool _initialLoading = false;
  bool _pagingLoading = false;
  bool _hasMore = true;

  // ✅ (필터는 없지만) MeetListView 패턴 유지용
  // refreshTick 역할: refresh를 여기서 자체적으로 올림
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
        .collection('meets')
        .doc(widget.meetId)
        .collection('lightnings')
        .where('status', isEqualTo: 'open')
        .orderBy('dateTime', descending: false);
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

  @override
  Widget build(BuildContext context) {
    // ✅ MeetListView 방식 유지(여기서는 refreshTick만)
    final newKey = _makeQueryKey();
    if (_queryKey != newKey) {
      _queryKey = newKey;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _resetAndFetch();
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('번개 전체보기', style: AppTextStyle.titleMediumBoldStyle),
        actions: [],
      ),
      body: RefreshIndicator(
        color: AppColors.sky400,
        backgroundColor: AppColors.bgWhite,
        onRefresh: () async {
          _triggerRefresh(); // refreshTick++
          await Future.delayed(const Duration(milliseconds: 250));
        },
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
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

    if (_docs.isEmpty) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 60, 16, 16),
        children: [
          Text(
            '아직 번개가 없어요',
            style: AppTextStyle.headlineSmallBoldStyle.copyWith(
              color: AppColors.textDefault,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Text(
            '모임친구들을 만나기위해 번개를 만들어 볼까요?',
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
                final created = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => LightningCreateView(meetId: widget.meetId),
                  ),
                );

                // ✅ isLive=false 기준:
                // 자동 갱신 X.
                // 원하면 "생성했을 때만" 수동 갱신:
                if (created == true) {
                  _triggerRefresh();
                  ref.invalidate(meetLightningSectionProvider(widget.meetId));
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.btnPrimary,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                '모임 만들기',
                style: AppTextStyle.titleMediumBoldStyle.copyWith(
                  color: AppColors.white,
                ),
              ),
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      controller: _scrollCtrl,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
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

        final d = _docs[index];
        final model = LightningModel.fromDoc(d);

        final now = DateTime.now();
        if (model.dateTime.isBefore(now.subtract(const Duration(minutes: 1)))) {
          return const SizedBox.shrink();
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: LightningCard(
            meetId: widget.meetId,
            model: model,
            isMeetMember: true,
          ),
        );
      },
    );
  }
}
