import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../common/common_text_field.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_constants.dart';
import '../../../constants/app_text_style.dart';

import '../domain/meet_model.dart';
import '../meet_create/meet_create_view.dart';
import '../meet_detail/meat_detail_view.dart';
import '../providers/meet_provider.dart';
import '../widget/empty_meet_list.dart';
import '../widget/meet_card.dart';
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
  final _searchCtrl = TextEditingController();

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
      final state = ref.read(meetListControllerProvider);
      _queryKey = _makeQueryKey(state);
      _searchCtrl.text = state.searchText;
      _resetAndFetch();
    });
  }

  @override
  void dispose() {
    _scrollCtrl.removeListener(_onScroll);
    _scrollCtrl.dispose();
    _searchCtrl.dispose();
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
    return '${state.selectSubType}_${state.searchText}_${state.refreshTick}';
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
      final controller = ref.read(meetListControllerProvider.notifier);
      Query<Map<String, dynamic>> q = controller.buildQuery().limit(
        MeetListController.pageSize,
      );

      final snap = await q.get();
      final newDocs = snap.docs;

      setState(() {
        _docs.addAll(newDocs);
        _lastDoc = newDocs.isNotEmpty ? newDocs.last : null;
        _hasMore = newDocs.length == MeetListController.pageSize;
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
      Query<Map<String, dynamic>> q = controller
          .buildQuery()
          .startAfterDocument(_lastDoc!)
          .limit(MeetListController.pageSize);

      final snap = await q.get();
      final newDocs = snap.docs;

      setState(() {
        _docs.addAll(newDocs);
        _lastDoc = newDocs.isNotEmpty ? newDocs.last : _lastDoc;
        _hasMore = newDocs.length == MeetListController.pageSize;
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

    if (_searchCtrl.text != state.searchText) {
      _searchCtrl.value = _searchCtrl.value.copyWith(
        text: state.searchText,
        selection: TextSelection.collapsed(offset: state.searchText.length),
      );
    }

    final newKey = _makeQueryKey(state);
    if (_queryKey != newKey) {
      _queryKey = newKey;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _resetAndFetch();
      });
    }

    return Scaffold(
      appBar: AppBar(title: const Text('전체 모임')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                GestureDetector(
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
                      transitionBuilder:
                          (context, animation, secondaryAnimation, child) {
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.bgWhite,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.borderSecondary),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.tune,
                          size: 18,
                          color: AppColors.icDefault,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          state.selectSubType,
                          style: AppTextStyle.labelMediumStyle.copyWith(
                            color: AppColors.textDefault,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(
                          Icons.expand_more,
                          color: AppColors.icSecondary,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: CommonTextField(
                    controller: _searchCtrl,
                    hintText: '모임 검색',
                    onChanged: controller.setSearchText,
                    suffixIcon: state.searchText.isNotEmpty
                        ? GestureDetector(
                            onTap: () {
                              _searchCtrl.clear();
                              controller.setSearchText('');
                            },
                            child: const Icon(
                              Icons.close,
                              color: AppColors.icSecondary,
                            ),
                          )
                        : const Icon(
                            Icons.search,
                            color: AppColors.icSecondary,
                          ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              color: AppColors.sky400,
              backgroundColor: AppColors.bgWhite,
              onRefresh: () async {
                controller.refresh();
                await Future.delayed(const Duration(milliseconds: 250));
              },
              child: _buildBody(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
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

    if (_docs.isEmpty) {
      return EmptyList(
        icon: Icons.people_rounded,
        btnTitle: '모임 만들기',
        title: '아직 모임이 없어요',
        subTitle: '운동친구를 모으는 첫 모임을 만들어볼까요?',
        onTapCreate: () {
          Navigator.push(
            context,
            CupertinoPageRoute(
              fullscreenDialog: true,
              builder: (_) => const MeetCreateStepperView(),
            ),
          );
        },
      );
    }

    return ListView.separated(
      controller: _scrollCtrl,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
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
