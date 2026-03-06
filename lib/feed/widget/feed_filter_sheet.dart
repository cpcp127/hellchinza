import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:hellchinza/common/common_chip.dart';
import 'package:hellchinza/constants/app_constants.dart';

import '../../constants/app_colors.dart';
import '../../constants/app_text_style.dart';

class FeedFilterWheelSheet extends StatefulWidget {
  const FeedFilterWheelSheet({
    super.key,
    required this.initialMainType,
    required this.initialSubType,
    required this.initialOnlyFriends,
    required this.onApply,
  });

  final String initialMainType;
  final String initialSubType;
  final bool initialOnlyFriends;
  final void Function(String main, String sub, bool onlyFriends) onApply;

  @override
  State<FeedFilterWheelSheet> createState() => _FeedFilterWheelSheetState();
}

class _FeedFilterWheelSheetState extends State<FeedFilterWheelSheet> {
  final List<String> mainTypes = ['전체', '오운완', '식단', '질문', '후기'];

  late final Map<String, List<String>> subTypesByMain = {
    '전체': ['전체', ...workList],
    '오운완': ['전체', ...workList],
    '식단': ['전체'],
    '질문': ['전체', ...workList],
    '후기': ['전체', ...workList],
  };

  late String _main;
  late String _sub;
  late bool _onlyFriends;

  late FixedExtentScrollController _mainCtrl;
  late FixedExtentScrollController _subCtrl;

  static const double _itemExtent = 72;

  @override
  void initState() {
    super.initState();

    _main = widget.initialMainType;
    _onlyFriends = widget.initialOnlyFriends;

    final initialSubList = subTypesByMain[_main] ?? ['전체'];
    _sub = initialSubList.contains(widget.initialSubType)
        ? widget.initialSubType
        : initialSubList.first;

    _mainCtrl = FixedExtentScrollController(
      initialItem: _safeIndex(mainTypes, _main),
    );
    _subCtrl = FixedExtentScrollController(
      initialItem: _safeIndex(initialSubList, _sub),
    );
  }

  @override
  void dispose() {
    _mainCtrl.dispose();
    _subCtrl.dispose();
    super.dispose();
  }

  int _safeIndex(List<String> items, String value) {
    final index = items.indexOf(value);
    return index < 0 ? 0 : index;
  }

  List<String> get _currentSubList => subTypesByMain[_main] ?? ['전체'];

  void _onMainChanged(int index) {
    final nextMain = mainTypes[index];
    final nextSubList = subTypesByMain[nextMain] ?? ['전체'];

    setState(() {
      _main = nextMain;
      if (!nextSubList.contains(_sub)) {
        _sub = nextSubList.first;
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _subCtrl.jumpToItem(_safeIndex(nextSubList, _sub));
    });
  }

  void _onSubChanged(int index) {
    final subList = _currentSubList;
    if (index < 0 || index >= subList.length) return;

    setState(() {
      _sub = subList[index];
    });
  }

  @override
  Widget build(BuildContext context) {
    final subList = _currentSubList;

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: Container(color: Colors.black.withOpacity(0.3)),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 14),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        behavior: HitTestBehavior.opaque,
                        child: const SizedBox(
                          width: 36,
                          height: 36,
                          child: Icon(
                            CupertinoIcons.chevron_down,
                            color: AppColors.white,
                            size: 24,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '피드 필터',
                        style: AppTextStyle.headlineSmallBoldStyle.copyWith(
                          color: AppColors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 20),
                Expanded(
                  child: Container(
                    child: Row(
                      children: [
                        Expanded(
                          child: _WheelColumn(
                            title: '메인',
                            controller: _mainCtrl,
                            items: mainTypes,
                            selectedValue: _main,
                            onSelectedItemChanged: _onMainChanged,
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 260,
                          color: Colors.white.withOpacity(0.10),
                        ),
                        Expanded(
                          child: _WheelColumn(
                            title: '서브',
                            controller: _subCtrl,
                            items: subList,
                            selectedValue: _sub,
                            onSelectedItemChanged: _onSubChanged,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(22, 0, 22, 18),
                    child: SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: () {
                          widget.onApply(_main, _sub, _onlyFriends);
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          elevation: 0,
                          backgroundColor: AppColors.btnPrimary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        child: Text(
                          '적용하기',
                          style: AppTextStyle.titleMediumBoldStyle.copyWith(
                            color: AppColors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WheelColumn extends StatelessWidget {
  const _WheelColumn({
    required this.title,
    required this.controller,
    required this.items,
    required this.selectedValue,
    required this.onSelectedItemChanged,
  });

  final String title;
  final FixedExtentScrollController controller;
  final List<String> items;
  final String selectedValue;
  final ValueChanged<int> onSelectedItemChanged;

  static const double _itemExtent = 72;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          title,
          style: AppTextStyle.labelLargeStyle.copyWith(
            color: Colors.white.withOpacity(0.72),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned(
                left: 18,
                right: 18,
                child: Container(
                  height: 64,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.white.withOpacity(0.10)),
                  ),
                ),
              ),
              ListWheelScrollView.useDelegate(
                controller: controller,
                itemExtent: _itemExtent,
                diameterRatio: 1.7,
                perspective: 0.003,
                squeeze: 0.96,
                physics: const FixedExtentScrollPhysics(),
                overAndUnderCenterOpacity: 0.32,
                onSelectedItemChanged: onSelectedItemChanged,
                childDelegate: ListWheelChildBuilderDelegate(
                  childCount: items.length,
                  builder: (context, index) {
                    final item = items[index];
                    final isSelected = item == selectedValue;

                    return Center(
                      child: AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 160),
                        style: AppTextStyle.headlineSmallMediumStyle.copyWith(
                          color: isSelected
                              ? AppColors.white
                              : Colors.white.withOpacity(0.42),
                        ),
                        child: Text(
                          item,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
