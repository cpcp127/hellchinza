import 'package:flutter/material.dart';
import 'package:hellchinza/common/common_text_field.dart';

import '../constants/app_colors.dart';
import '../constants/app_text_style.dart';

class PollBuilder extends StatefulWidget {
  final List<String> options;
  final VoidCallback onAdd;
  final void Function(int index) onRemove;
  final void Function(int index, String value) onChange;

  const PollBuilder({
    super.key,
    required this.options,
    required this.onAdd,
    required this.onRemove,
    required this.onChange,
  });

  @override
  State<PollBuilder> createState() => _PollBuilderState();
}

class _PollBuilderState extends State<PollBuilder> {
  final List<TextEditingController> _controllers = [];

  @override
  void initState() {
    super.initState();
    _syncControllers();
  }

  @override
  void didUpdateWidget(covariant PollBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncControllers();
  }

  void _syncControllers() {
    // 길이 맞추기
    while (_controllers.length < widget.options.length) {
      _controllers.add(TextEditingController());
    }
    while (_controllers.length > widget.options.length) {
      _controllers.removeLast().dispose();
    }

    // 값 동기화 + 안전한 커서 위치
    for (int i = 0; i < widget.options.length; i++) {
      final text = widget.options[i];
      final c = _controllers[i];

      if (c.text != text) {
        c.value = c.value.copyWith(
          text: text,
          selection: TextSelection.collapsed(
            offset: text.length, // 항상 안전
          ),
          composing: TextRange.empty,
        );
      }
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canAdd = widget.options.length < 6;
    final showEmptyHint = widget.options.isEmpty;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderSecondary),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '선택지를 추가해 투표를 만들 수 있어요',
            style: AppTextStyle.bodySmallStyle.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),

          if (showEmptyHint)
            _PollEmptyHint(onTap: widget.onAdd)
          else
            Column(
              children: List.generate(widget.options.length, (i) {
                return Padding(
                  padding: EdgeInsets.only(
                    bottom: i == widget.options.length - 1 ? 0 : 10,
                  ),
                  child: _PollOptionField(
                    index: i,
                    controller: _controllers[i],
                    onChanged: (v) => widget.onChange(i, v),
                    onRemove: () => widget.onRemove(i),
                    canRemove: widget.options.length > 2,
                  ),
                );
              }),
            ),

          const SizedBox(height: 12),

          GestureDetector(
            onTap: canAdd ? widget.onAdd : null,
            behavior: HitTestBehavior.translucent,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: canAdd ? AppColors.sky50 : AppColors.bgSecondary,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: canAdd
                      ? AppColors.borderPrimary
                      : AppColors.borderSecondary,
                ),
              ),
              child: Center(
                child: Text(
                  '선택지 추가',
                  style: AppTextStyle.labelMediumStyle.copyWith(
                    color: canAdd
                        ? AppColors.textPrimary
                        : AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 8),
          Text(
            '${widget.options.length}/6',
            style: AppTextStyle.labelSmallStyle.copyWith(
              color: AppColors.textTeritary,
            ),
          ),
        ],
      ),
    );
  }
}


class _PollEmptyHint extends StatelessWidget {
  final VoidCallback onTap;
  const _PollEmptyHint({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.translucent,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: AppColors.bgSecondary,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderSecondary),
        ),
        child: Column(
          children: [
            Icon(Icons.poll_outlined, color: AppColors.icSecondary, size: 28),
            const SizedBox(height: 6),
            Text(
              '선택지를 추가해 투표를 시작해보세요',
              style: AppTextStyle.labelMediumStyle.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PollOptionField extends StatelessWidget {
  final int index;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onRemove;
  final bool canRemove;

  const _PollOptionField({
    required this.index,
    required this.controller,
    required this.onChanged,
    required this.onRemove,
    required this.canRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.bgWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderSecondary),
      ),
      child: Row(
        children: [
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.sky50,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: AppColors.borderPrimary),
            ),
            child: Text(
              '${index + 1}',
              style: AppTextStyle.labelSmallStyle.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: 10),

          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              maxLength: 25,
              decoration: InputDecoration(
                counterText: '',
                hintText: '선택지 내용을 입력하세요',
                hintStyle: AppTextStyle.bodySmallStyle.copyWith(
                  color: AppColors.textTeritary,
                ),
                border: InputBorder.none,
                isDense: true,
              ),
              style: AppTextStyle.bodyMediumStyle.copyWith(
                color: AppColors.textDefault,
              ),
            ),
          ),

          if (canRemove)
            GestureDetector(
              onTap: onRemove,
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: AppColors.bgSecondary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.close,
                  size: 16,
                  color: AppColors.icSecondary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
