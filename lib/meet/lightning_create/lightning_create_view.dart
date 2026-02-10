import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hellchinza/common/common_chip.dart';

import '../../common/common_action_sheet.dart';
import '../../common/common_location_serach_view.dart';
import '../../common/common_text_field.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_constants.dart';
import '../../constants/app_text_style.dart';
import '../../feed/create_feed/create_feed_state.dart';
import 'lightning_create_controller.dart';
import 'lightning_create_state.dart';

class LightningCreateView extends ConsumerStatefulWidget {
  const LightningCreateView({super.key, required this.meetId});

  final String meetId;

  @override
  ConsumerState<LightningCreateView> createState() =>
      _LightningCreateViewState();
}

class _LightningCreateViewState extends ConsumerState<LightningCreateView> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _maxCtrl;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController();
    _maxCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _maxCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(lightningCreateControllerProvider(widget.meetId));
    final controller = ref.read(
      lightningCreateControllerProvider(widget.meetId).notifier,
    );

    // 컨트롤러 값 동기화(간단 버전)
    if (_titleCtrl.text != state.title) {
      _titleCtrl.value = _titleCtrl.value.copyWith(
        text: state.title,
        selection: TextSelection.collapsed(offset: state.title.length),
      );
    }
    final maxText = state.maxMembersText?.toString() ?? '';
    if (_maxCtrl.text != maxText) {
      _maxCtrl.value = _maxCtrl.value.copyWith(
        text: maxText,
        selection: TextSelection.collapsed(offset: maxText.length),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.bgWhite,
      appBar: AppBar(
        title: Text('번개 만들기', style: AppTextStyle.titleMediumBoldStyle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: state.isLoading
              ? null
              : () => controller.onTapLeading(context),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            _StepHeaderLikeMeet(
              // ✅ 모임 만들기 헤더랑 동일한 스타일로
              stepIndex: state.stepIndex,
              total: 5,
              title: _stepTitle(state.stepIndex),
            ),

            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                child: _StepBody(
                  state: state,
                  controller: controller,
                  titleCtrl: _titleCtrl,
                  maxCtrl: _maxCtrl,
                  meetId: widget.meetId,
                ),
              ),
            ),

            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: state.isLoading
                        ? null
                        : (state.canGoNext
                              ? () async {
                                  if (!state.isLast) {
                                    controller.nextStep();
                                    return;
                                  }
                                  final ok = await controller.submit();
                                  if (!context.mounted) return;
                                  if (ok) Navigator.pop(context, true);
                                }
                              : null),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.btnPrimary,
                      disabledBackgroundColor: AppColors.btnDisabled,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: state.isLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            state.isLast ? '번개 만들기' : '다음',
                            style: AppTextStyle.labelLargeStyle.copyWith(
                              color: AppColors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _stepTitle(int i) {
  switch (i) {
    case 0:
      return '번개 타이틀';
    case 1:
      return '운동 종류 선택';
    case 2:
      return '시간 선택';
    case 3:
      return '최대 인원';
    case 4:
      return '장소 · 썸네일';
    default:
      return '';
  }
}

class _StepHeaderLikeMeet extends StatelessWidget {
  const _StepHeaderLikeMeet({
    required this.stepIndex,
    required this.total,
    required this.title,
  });

  final int stepIndex;
  final int total;
  final String title;

  @override
  Widget build(BuildContext context) {
    final current = stepIndex + 1;
    final v = (current / total).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$current/$total',
            style: AppTextStyle.labelSmallStyle.copyWith(
              color: AppColors.textTeritary,
            ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: v,
              minHeight: 6,
              backgroundColor: AppColors.gray100,
              valueColor: const AlwaysStoppedAnimation(AppColors.sky400),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepBody extends StatelessWidget {
  const _StepBody({
    required this.state,
    required this.controller,
    required this.titleCtrl,
    required this.maxCtrl,
    required this.meetId,
  });

  final LightningCreateState state;
  final LightningCreateController controller;
  final TextEditingController titleCtrl;
  final TextEditingController maxCtrl;
  final String meetId;

  @override
  Widget build(BuildContext context) {
    switch (state.stepIndex) {
      case 0:
        return _StepTitleInput(
          ctrl: titleCtrl,
          onChanged: controller.onChangeTitle,
        );

      case 1:
        return _StepCategoryPick(
          selected: state.category,
          onSelect: controller.onSelectCategory,
        );

      case 2:
        return _StepDateTimePick(
          value: state.dateTime,
          onPick: (dt) => controller.onSelectDateTime(dt),
        );

      case 3:
        return _StepMaxMembers(
          ctrl: maxCtrl,
          onChanged: controller.onChangeMaxMembersText,
        );

      case 4:
        return _StepPlaceAndThumb(
          state: state,
          controller: controller,
          onPickPlace: () async {
            // ✅ 너의 “장소 검색 바텀시트”를 여기서 호출해서 place를 받아와야 함
            // 예:
            // final place = await showPlacePickerBottomSheet(context);
            // if (place != null) controller.onSelectPlace(place);

            // 지금은 TODO로 남겨둠
          },
        );

      default:
        return const SizedBox.shrink();
    }
  }
}

class _StepTitleInput extends StatelessWidget {
  const _StepTitleInput({required this.ctrl, required this.onChanged});

  final TextEditingController ctrl;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('번개 이름을 입력해주세요', style: AppTextStyle.titleMediumBoldStyle),
        const SizedBox(height: 10),
        CommonTextField(
          controller: ctrl,
          hintText: '예) 반포 한강 러닝 번개',
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _StepCategoryPick extends StatelessWidget {
  const _StepCategoryPick({required this.selected, required this.onSelect});

  final String? selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('어떤 운동 번개인가요?', style: AppTextStyle.titleMediumBoldStyle),
        const SizedBox(height: 10),
        CommonChipWrap(
          items: workList,
          selectedItems: selected==null?[]:[selected!],
          onTap: (str) => onSelect(str),
        ),

      ],
    );
  }
}

class _StepDateTimePick extends StatelessWidget {
  const _StepDateTimePick({required this.value, required this.onPick});

  final DateTime? value;
  final ValueChanged<DateTime> onPick;

  @override
  Widget build(BuildContext context) {
    final text = value == null ? '시간을 선택해주세요' : _format(value!);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('언제 모일까요?', style: AppTextStyle.titleMediumBoldStyle),
        const SizedBox(height: 10),
        InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () async {
            final picked = await _showCupertinoDateTimePicker(
              context,
              initial: value,
            );
            if (picked != null) onPick(picked);
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.borderSecondary),
            ),
            child: Text(
              text,
              style: AppTextStyle.bodyMediumStyle.copyWith(
                color: value == null
                    ? AppColors.textTeritary
                    : AppColors.textDefault,
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _format(DateTime dt) {
    // ✅ 네 DateTimeUtil._formatMeetDateTime 넣을 자리
    return '${dt.month}월 ${dt.day}일 ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  Future<DateTime?> _showCupertinoDateTimePicker(
    BuildContext context, {
    DateTime? initial,
  }) async {
    DateTime now = DateTime.now();
    final minimum = now;

    DateTime temp = initial ?? now.add(const Duration(minutes: 10));
    // ✅ minimum 보다 과거면 끌어올리기
    if (temp.isBefore(minimum)) temp = minimum.add(const Duration(minutes: 5));
    // ✅ minuteInterval(5) 맞추기
    temp = DateTime(
      temp.year,
      temp.month,
      temp.day,
      temp.hour,
      (temp.minute ~/ 5) * 5,
    );

    DateTime? result = temp;

    return showModalBottomSheet<DateTime>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) {
        return Container(
          height: 360,
          decoration: const BoxDecoration(
            color: AppColors.bgWhite,
            borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: AppColors.gray200,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('취소', style: AppTextStyle.labelMediumStyle),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.pop(context, result),
                    child: Text(
                      '확인',
                      style: AppTextStyle.labelMediumStyle.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              Expanded(
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.dateAndTime,
                  minuteInterval: 5,
                  minimumDate: minimum,
                  maximumDate: DateTime(now.year + 1),
                  initialDateTime: temp,
                  onDateTimeChanged: (v) {
                    // minimum 보장 + 5분 단위 보정
                    DateTime vv = v;
                    if (vv.isBefore(minimum)) vv = minimum;
                    vv = DateTime(
                      vv.year,
                      vv.month,
                      vv.day,
                      vv.hour,
                      (vv.minute ~/ 5) * 5,
                    );
                    result = vv;
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StepMaxMembers extends StatelessWidget {
  const _StepMaxMembers({required this.ctrl, required this.onChanged});

  final TextEditingController ctrl;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('최대 몇 명까지 받을까요?', style: AppTextStyle.titleMediumBoldStyle),
        const SizedBox(height: 10),
        CommonTextField(
          controller: ctrl,
          hintText: '예) 8',
          keyboardType: TextInputType.number,

          onChanged: onChanged,
        ),
        const SizedBox(height: 8),
        Text(
          '2~200 사이 숫자를 입력해주세요',
          style: AppTextStyle.bodySmallStyle.copyWith(
            color: AppColors.textTeritary,
          ),
        ),
      ],
    );
  }
}

class _StepPlaceAndThumb extends StatelessWidget {
  const _StepPlaceAndThumb({
    required this.state,
    required this.controller,
    required this.onPickPlace,
  });

  final LightningCreateState state;
  final LightningCreateController controller;
  final VoidCallback onPickPlace;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('장소를 선택해주세요', style: AppTextStyle.titleMediumBoldStyle),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: () async {
            final FeedPlace? selected = await Navigator.push(
              context,
              CupertinoPageRoute(
                fullscreenDialog: true,
                builder: (context) {
                  return CommonLocationSearchView();
                },
              ),
            );

            if (selected == null) return;

            controller.onSelectPlace(selected);
          },
          child: state.selectedPlace == null
              ? Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 14,
            ),
            decoration: BoxDecoration(
              color: AppColors.bgSecondary,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.borderSecondary),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.place_outlined,
                  size: 20,
                  color: AppColors.icSecondary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '어디서 만날까요?',
                    style: AppTextStyle.bodyMediumStyle.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                const Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: AppColors.icSecondary,
                ),
              ],
            ),
          )
              : Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.bgWhite,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.borderSecondary),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.place_outlined,
                  color: AppColors.icSecondary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        state.selectedPlace!.title,
                        style: AppTextStyle.titleSmallBoldStyle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        state.selectedPlace!.address,
                        style: AppTextStyle.bodySmallStyle.copyWith(
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right,
                  color: AppColors.icSecondary,
                ),
              ],
            ),
          ),
        ),


      ],
    );
  }

}



