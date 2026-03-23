import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hellchinza/common/common_action_sheet.dart';
import 'package:hellchinza/common/common_chip.dart';
import 'package:hellchinza/common/common_location_serach_view.dart';
import 'package:hellchinza/common/common_text_field.dart';
import 'package:hellchinza/constants/app_colors.dart';
import 'package:hellchinza/constants/app_constants.dart';
import 'package:hellchinza/constants/app_text_style.dart';
import 'package:hellchinza/feed/domain/feed_place.dart';

import 'package:hellchinza/meet/providers/meet_provider.dart';

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
          onPick: controller.onSelectDateTime,
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
            final place = await Navigator.push<FeedPlace>(
              context,
              MaterialPageRoute(
                builder: (_) => const CommonLocationSearchView(),
              ),
            );

            if (place != null) {
              controller.onSelectPlace(place);
            }
          },
        );
      default:
        return const SizedBox.shrink();
    }
  }
}

class _StepTitleInput extends StatelessWidget {
  const _StepTitleInput({
    required this.ctrl,
    required this.onChanged,
  });

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
  const _StepCategoryPick({
    required this.selected,
    required this.onSelect,
  });

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
          selectedItems: selected == null ? [] : [selected!],
          onTap: onSelect,
        ),
      ],
    );
  }
}

class _StepDateTimePick extends StatelessWidget {
  const _StepDateTimePick({
    required this.value,
    required this.onPick,
  });

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
    return '${dt.month}월 ${dt.day}일 ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

class _StepMaxMembers extends StatelessWidget {
  const _StepMaxMembers({
    required this.ctrl,
    required this.onChanged,
  });

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
          hintText: '2~200',
          keyboardType: TextInputType.number,
          onChanged: onChanged,
          suffixIcon: const Padding(
            padding: EdgeInsets.only(right: 12),
            child: Center(
              widthFactor: 1,
              child: Text('명'),
            ),
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
    final placeText = state.selectedPlace == null
        ? '장소를 선택해주세요'
        : state.selectedPlace!.title;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('어디서 진행하나요?', style: AppTextStyle.titleMediumBoldStyle),
          const SizedBox(height: 10),
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onPickPlace,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.borderSecondary),
              ),
              child: Text(
                placeText,
                style: AppTextStyle.bodyMediumStyle.copyWith(
                  color: state.selectedPlace == null
                      ? AppColors.textTeritary
                      : AppColors.textDefault,
                ),
              ),
            ),
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Text('썸네일', style: AppTextStyle.titleMediumBoldStyle),
              const Spacer(),
              if (state.thumbnail != null)
                TextButton(
                  onPressed: controller.removeThumbnail,
                  child: Text(
                    '삭제',
                    style: AppTextStyle.labelMediumStyle.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => _showImagePickActionSheet(context),
            child: Container(
              width: double.infinity,
              height: 220,
              decoration: BoxDecoration(
                color: AppColors.bgSecondary,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.borderSecondary),
              ),
              child: state.thumbnail == null
                  ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.add_a_photo_outlined,
                    size: 30,
                    color: AppColors.icSecondary,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '썸네일 추가',
                    style: AppTextStyle.bodyMediumStyle.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              )
                  : ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Image.file(
                  File(state.thumbnail!.path),
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showImagePickActionSheet(BuildContext context) async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => CommonActionSheet(
        title: '썸네일 선택',
        items: [
          CommonActionSheetItem(
            icon: Icons.photo_library_outlined,
            title: '앨범에서 선택',
            onTap: () async {
              Navigator.pop(context);
              await controller.pickThumbnailToAlbum(context);
            },
          ),
          CommonActionSheetItem(
            icon: Icons.photo_camera_outlined,
            title: '카메라로 촬영',
            onTap: () async {
              Navigator.pop(context);
              await controller.pickThumbnailToAlbumToCamera(context);
            },
          ),
        ],
      ),
    );
  }
}

Future<DateTime?> _showCupertinoDateTimePicker(
    BuildContext context, {
      DateTime? initial,
    }) async {
  DateTime temp = initial ?? DateTime.now().add(const Duration(hours: 1));

  final result = await showCupertinoModalPopup<DateTime>(
    context: context,
    builder: (_) {
      return Container(
        height: 300,
        color: Colors.white,
        child: Column(
          children: [
            Container(
              height: 52,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('취소'),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.pop(context, temp),
                    child: const Text('확인'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.dateAndTime,
                initialDateTime: temp,
                minimumDate: DateTime.now(),
                use24hFormat: true,
                onDateTimeChanged: (v) => temp = v,
              ),
            ),
          ],
        ),
      );
    },
  );

  return result;
}