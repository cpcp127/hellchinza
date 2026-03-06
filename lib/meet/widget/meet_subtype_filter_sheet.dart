import 'dart:ui';

import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';
import '../../constants/app_text_style.dart';

class MeetSubTypeFilterSheet extends StatefulWidget {
  const MeetSubTypeFilterSheet({
    super.key,
    required this.initialValue,
    required this.items,
    required this.onApply,
  });

  final String initialValue;
  final List<String> items;
  final ValueChanged<String> onApply;

  @override
  State<MeetSubTypeFilterSheet> createState() => _MeetSubTypeFilterSheetState();
}

class _MeetSubTypeFilterSheetState extends State<MeetSubTypeFilterSheet> {
  late String _selected;
  late FixedExtentScrollController _scrollCtrl;

  static const double _itemExtent = 72;

  @override
  void initState() {
    super.initState();
    _selected = widget.items.contains(widget.initialValue)
        ? widget.initialValue
        : widget.items.first;

    _scrollCtrl = FixedExtentScrollController(
      initialItem: widget.items.indexOf(_selected),
    );
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: Container(
                  color: Colors.black.withOpacity(0.58),
                ),
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
                            Icons.keyboard_arrow_down,
                            size: 28,
                            color: AppColors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '운동 종류',
                        style: AppTextStyle.headlineSmallBoldStyle.copyWith(
                          color: AppColors.white,
                        ),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _selected = '전체';
                          });
                          _scrollCtrl.jumpToItem(
                            widget.items.indexOf('전체'),
                          );
                        },
                        child: Text(
                          '초기화',
                          style: AppTextStyle.bodyMediumStyle.copyWith(
                            color: Colors.white.withOpacity(0.82),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                SizedBox(
                  height: 360,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Positioned(
                        left: 24,
                        right: 24,
                        child: Container(
                          height: 64,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.10),
                            ),
                          ),
                        ),
                      ),
                      ListWheelScrollView.useDelegate(
                        controller: _scrollCtrl,
                        itemExtent: _itemExtent,
                        diameterRatio: 1.7,
                        perspective: 0.003,
                        squeeze: 0.96,
                        physics: const FixedExtentScrollPhysics(),
                        overAndUnderCenterOpacity: 0.32,
                        onSelectedItemChanged: (index) {
                          setState(() {
                            _selected = widget.items[index];
                          });
                        },
                        childDelegate: ListWheelChildBuilderDelegate(
                          childCount: widget.items.length,
                          builder: (context, index) {
                            final item = widget.items[index];
                            final isSelected = item == _selected;

                            return Center(
                              child: AnimatedDefaultTextStyle(
                                duration: const Duration(milliseconds: 160),
                                style: AppTextStyle.headlineSmallMediumStyle
                                    .copyWith(
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
                const Spacer(),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(22, 0, 22, 18),
                    child: SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: () {
                          widget.onApply(_selected);
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