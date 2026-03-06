import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_pagination/firebase_pagination.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hellchinza/meet/domain/meet_model.dart';
import 'package:hellchinza/meet/meet_detail/meat_detail_view.dart';
import 'package:hellchinza/meet/widget/empty_meet_list.dart';
import 'package:hellchinza/meet/widget/meet_card.dart';

import '../../common/common_chip.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_constants.dart';
import '../../constants/app_text_style.dart';
import '../meet_create/meet_create_view.dart';
import '../widget/meet_subtype_filter_sheet.dart';
import 'meet_list_controller.dart';
import 'meet_list_state.dart';

class MeetListView extends ConsumerStatefulWidget {
  const MeetListView({super.key});

  @override
  ConsumerState<MeetListView> createState() => _MeetListViewState();
}

class _MeetListViewState extends ConsumerState<MeetListView> {
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
      // ✅ 첫 진입도 key 세팅 후 fetch
      final state = ref.read(meetListControllerProvider);
      _queryKey = _makeQueryKey(state);
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

  String _makeQueryKey(MeetListState state) {
    // ✅ FirestorePagination key와 동일 개념
    return '${state.selectSubType}_${state.refreshTick}';
  }

  Future<void> _resetAndFetch() async {
    // ✅ 중복 호출 방지(필터 바뀔 때 프레임 겹칠 수 있음)
    if (_initialLoading) return;

    setState(() {
      _docs.clear();
      _lastDoc = null;
      _hasMore = true;
      _initialLoading = true;
      _pagingLoading = false;
    });

    try {
      final controller = ref.read(meetListControllerProvider.notifier);
      Query<Map<String, dynamic>> q = controller.buildQuery();

      q = q.limit(12);

      final snap = await q.get();
      final newDocs = snap.docs;

      setState(() {
        _docs.addAll(newDocs);
        _lastDoc = newDocs.isNotEmpty ? newDocs.last : null;
        _hasMore = newDocs.length == 12;
        _initialLoading = false;
      });
    } catch (e) {
      setState(() {
        _initialLoading = false;
      });
    }
  }

  Future<void> _fetchNext() async {
    if (!_hasMore) return;
    if (_lastDoc == null) return;
    if (_pagingLoading) return;

    setState(() => _pagingLoading = true);

    try {
      final controller = ref.read(meetListControllerProvider.notifier);
      Query<Map<String, dynamic>> q = controller.buildQuery();

      q = q.startAfterDocument(_lastDoc!).limit(12);

      final snap = await q.get();
      final newDocs = snap.docs;

      setState(() {
        _docs.addAll(newDocs);
        _lastDoc = newDocs.isNotEmpty ? newDocs.last : _lastDoc;
        _hasMore = newDocs.length == 12;
        _pagingLoading = false;
      });
    } catch (e) {
      setState(() => _pagingLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.read(meetListControllerProvider.notifier);
    final state = ref.watch(meetListControllerProvider);

    // ✅✅✅ 핵심: 피드와 동일 "쿼리키가 바뀌면 리셋"
    final newKey = _makeQueryKey(state);
    if (_queryKey != newKey) {
      _queryKey = newKey;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // 프레임 이후 리셋(빌드 중 setState 방지)
        _resetAndFetch();
      });
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Align(
            alignment: Alignment.centerLeft,
            child: GestureDetector(
              onTap: () async {
                await showGeneralDialog(
                  context: context,
                  barrierLabel: 'meet_subtype_filter',
                  barrierDismissible: true,
                  barrierColor: Colors.black.withOpacity(0.55),
                  transitionDuration: const Duration(milliseconds: 220),
                  pageBuilder: (_, __, ___) {
                    return MeetSubTypeFilterSheet(
                      initialValue: state.selectSubType,
                      items: ['전체', ...workList],
                      onApply: (value) {
                        controller.onChangeSubType(value);
                      },
                    );
                  },
                  transitionBuilder: (context, animation, secondaryAnimation, child) {
                    final curved = CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOutCubic,
                    );

                    return FadeTransition(
                      opacity: curved,
                      child: child,
                    );
                  },
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.bgWhite,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.borderSecondary),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.tune, size: 18, color: AppColors.icDefault),
                    const SizedBox(width: 8),
                    Text(
                      state.selectSubType,
                      style: AppTextStyle.labelMediumStyle.copyWith(
                        color: AppColors.textDefault,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.expand_more, color: AppColors.icSecondary),
                  ],
                ),
              ),
            ),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            color: AppColors.sky400,
            backgroundColor: AppColors.bgWhite,
            onRefresh: () async {
              controller.refresh(); // refreshTick++
              await Future.delayed(const Duration(milliseconds: 250));
              // ✅ 리셋은 queryKey 감지로 자동
            },
            child: _buildBody(state),
          ),
        ),
      ],
    );
  }

  Widget _buildBody(MeetListState state) {
    // ✅ 처음 로딩
    if (_initialLoading) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
        children: const [
          SizedBox(height: 24),
          Center(child: CircularProgressIndicator()),
        ],
      );
    }

    // ✅ empty
    if (_docs.isEmpty) {
      return EmptyMeetList(
        onTapCreate: () {
          Navigator.push(
            context,
            CupertinoPageRoute(
              fullscreenDialog: true,
              builder: (_) => MeetCreateStepperView(),
            ),
          );
        },
      );
    }

    // ✅ list
    return ListView.separated(
      controller: _scrollCtrl,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      itemCount: _docs.length + 1, // bottom loader 자리
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        if (index == _docs.length) {
          // ✅ 더 불러올게 없으면 로더도 숨김
          if (!_hasMore) return const SizedBox(height: 12);

          if (!_pagingLoading) return const SizedBox(height: 12);
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final doc = _docs[index];
        final item = MeetModel.fromDoc(doc);

        return MeetCard(
          item: item,
          onTap: () {
            Navigator.push(
              context,
              CupertinoPageRoute(
                fullscreenDialog: true,
                builder: (_) => MeetDetailView(meetId: item.id),
              ),
            );
          },
        );
      },
    );
  }
}
