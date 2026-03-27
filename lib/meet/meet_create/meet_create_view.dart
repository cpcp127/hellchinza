import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hellchinza/common/common_chip.dart';
import 'package:hellchinza/common/common_network_image.dart';
import 'package:hellchinza/common/common_text_field.dart';
import 'package:hellchinza/constants/app_colors.dart';
import 'package:hellchinza/constants/app_constants.dart';
import 'package:hellchinza/constants/app_text_style.dart';

import 'package:hellchinza/meet/providers/meet_provider.dart';

import '../widget/region_picker_sheet.dart';
import 'meet_create_controller.dart';
import 'meet_create_state.dart';

class MeetCreateStepperView extends ConsumerStatefulWidget {
  const MeetCreateStepperView({super.key, this.meetId});

  final String? meetId;

  @override
  ConsumerState<MeetCreateStepperView> createState() =>
      _MeetCreateStepperViewState();
}

class _MeetCreateStepperViewState extends ConsumerState<MeetCreateStepperView> {
  late final TextEditingController titleCtrl;
  late final TextEditingController introCtrl;
  late final TextEditingController maxCtrl;

  bool _initedEdit = false;

  @override
  void initState() {
    super.initState();
    final s = ref.read(meetCreateControllerProvider);
    titleCtrl = TextEditingController(text: s.title);
    introCtrl = TextEditingController(text: s.intro);
    maxCtrl = TextEditingController(text: s.maxMembersText);
  }

  @override
  void dispose() {
    titleCtrl.dispose();
    introCtrl.dispose();
    maxCtrl.dispose();
    super.dispose();
  }

  void _syncTextControllersFromState() {
    final s = ref.read(meetCreateControllerProvider);

    if (titleCtrl.text != s.title) titleCtrl.text = s.title;
    if (introCtrl.text != s.intro) introCtrl.text = s.intro;
    if (maxCtrl.text != s.maxMembersText) maxCtrl.text = s.maxMembersText;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(meetCreateControllerProvider);
    final controller = ref.read(meetCreateControllerProvider.notifier);

    if (!_initedEdit && widget.meetId != null) {
      _initedEdit = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await controller.initForEdit(widget.meetId!);
        _syncTextControllersFromState();
      });
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _syncTextControllersFromState();
    });

    return Scaffold(
      backgroundColor: AppColors.bgWhite,
      appBar: AppBar(
        backgroundColor: AppColors.bgWhite,
        elevation: 0,
        title: Text(
          state.isEdit ? '모임 수정' : '모임 만들기',
          style: AppTextStyle.titleMediumBoldStyle,
        ),
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: AppColors.icDefault,
          ),
          onPressed: () {
            if (state.step == 0) {
              Navigator.pop(context);
            } else {
              controller.back();
            }
          },
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            _StepIndicator(step: state.step, total: 6),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                child: _buildStep(context, state, controller),
              ),
            ),
            if (state.errorMessage != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    state.errorMessage!,
                    style: AppTextStyle.bodySmallStyle.copyWith(
                      color: AppColors.textError,
                    ),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: (state.canGoNext && !state.isLoading)
                      ? () async {
                    if (!state.isLast) {
                      controller.next();
                      return;
                    }
                    await controller.submit();
                    if (!mounted) return;
                    Navigator.pop(context, true);
                  }
                      : null,
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
                      color: AppColors.white,
                    ),
                  )
                      : Text(
                    state.isLast
                        ? (state.isEdit ? '수정 완료' : '생성 완료')
                        : '다음',
                    style: AppTextStyle.labelLargeStyle.copyWith(
                      color: AppColors.white,
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

  Widget _buildStep(
      BuildContext context,
      MeetCreateState state,
      MeetCreateController controller,
      ) {
    switch (state.step) {
      case 0:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('모임 이름', style: AppTextStyle.titleSmallBoldStyle),
            const SizedBox(height: 10),
            CommonTextField(
              controller: titleCtrl,
              hintText: '예) 한강 러닝 크루',
              onChanged: controller.setTitle,
            ),
            const SizedBox(height: 18),
            Text('모임 설명', style: AppTextStyle.titleSmallBoldStyle),
            const SizedBox(height: 10),
            CommonTextField(
              controller: introCtrl,
              hintText: '어떤 모임인지 간단히 소개해주세요',
              minLines: 5,
              maxLines: 15,
              onChanged: controller.setIntro,
            ),
          ],
        );

      case 1:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('운동 종류 선택', style: AppTextStyle.titleSmallBoldStyle),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: workList
                  .map(
                    (w) => CommonChip(
                  label: w,
                  selected: state.category == w,
                  onTap: () => controller.selectCategory(w),
                ),
              )
                  .toList(),
            ),
          ],
        );

      case 2:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('주요 활동 지역', style: AppTextStyle.titleSmallBoldStyle),
            const SizedBox(height: 10),
            InkWell(
              onTap: () async {
                final picked = await showRegionPickerBottomSheet(context);
                if (picked != null) controller.addRegion(picked);
              },
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.bgSecondary,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.borderSecondary),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.search,
                      size: 18,
                      color: AppColors.icSecondary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '동/읍/면 검색해서 추가하기',
                        style: AppTextStyle.bodyMediumStyle.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right,
                      color: AppColors.icDisabled,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (state.regions.isEmpty)
              Text(
                '선택된 지역이 없어요. 최소 1개 이상 추가해주세요.',
                style: AppTextStyle.bodySmallStyle.copyWith(
                  color: AppColors.textSecondary,
                ),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: state.regions
                    .map(
                      (r) => _SelectedRegionChip(
                    label: r.fullName,
                    onDelete: () => controller.removeRegion(r.code),
                  ),
                )
                    .toList(),
              ),
          ],
        );

      case 3:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('최대 인원', style: AppTextStyle.titleSmallBoldStyle),
            const SizedBox(height: 10),
            CommonTextField(
              controller: maxCtrl,
              hintText: '숫자만 입력 (2~1000)',
              keyboardType: TextInputType.number,
              onChanged: controller.setMaxMembersText,
            ),
          ],
        );

      case 4:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('참여 승인받기', style: AppTextStyle.titleSmallBoldStyle),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              decoration: BoxDecoration(
                color: AppColors.bgSecondary,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.borderSecondary),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '호스트 승인을 받아야 참가할 수 있어요',
                      style: AppTextStyle.bodyMediumStyle.copyWith(
                        color: AppColors.textDefault,
                      ),
                    ),
                  ),
                  CupertinoSwitch(
                    value: state.needApproval,
                    onChanged: controller.toggleNeedApproval,
                  ),
                ],
              ),
            ),
          ],
        );

      case 5:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('모임 썸네일', style: AppTextStyle.titleSmallBoldStyle),
            const SizedBox(height: 10),
            InkWell(
              onTap: state.isLoading
                  ? null
                  : () => controller.pickThumbnail(context),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                width: double.infinity,
                height: 220,
                decoration: BoxDecoration(
                  color: AppColors.bgSecondary,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.borderSecondary),
                ),
                child: _buildThumbnail(state),
              ),
            ),
            const SizedBox(height: 10),
            if (state.thumbnail != null ||
                (state.existingThumbnailUrl != null &&
                    !state.removeExistingThumbnail))
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed:
                  state.isLoading ? null : controller.removeThumbnail,
                  child: Text(
                    '썸네일 제거',
                    style: AppTextStyle.labelMediumStyle.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
          ],
        );

      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildThumbnail(MeetCreateState state) {
    if (state.thumbnail != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Image.file(
          File(state.thumbnail!.path) ,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
        ),
      );
    }

    if (state.existingThumbnailUrl != null && !state.removeExistingThumbnail) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: CommonNetworkImage(
          imageUrl: state.existingThumbnailUrl!,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          enableViewer: false,
        ),
      );
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(
          Icons.add_photo_alternate_outlined,
          size: 36,
          color: AppColors.icSecondary,
        ),
        const SizedBox(height: 8),
        Text(
          '썸네일 업로드',
          style: AppTextStyle.bodyMediumStyle.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _StepIndicator extends StatelessWidget {
  const _StepIndicator({
    required this.step,
    required this.total,
  });

  final int step;
  final int total;

  @override
  Widget build(BuildContext context) {
    final current = step + 1;
    final progress = current / total;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                '$current / $total',
                style: AppTextStyle.labelSmallStyle.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: progress,
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

class _SelectedRegionChip extends StatelessWidget {
  const _SelectedRegionChip({
    required this.label,
    required this.onDelete,
  });

  final String label;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(left: 12, right: 8, top: 8, bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.bgSecondary,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.borderSecondary),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: AppTextStyle.labelMediumStyle.copyWith(
              color: AppColors.textDefault,
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: onDelete,
            child: const Icon(
              Icons.close,
              size: 16,
              color: AppColors.icSecondary,
            ),
          ),
        ],
      ),
    );
  }
}