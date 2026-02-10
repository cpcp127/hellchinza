import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hellchinza/common/common_chip.dart';
import 'package:hellchinza/meet/domain/meet_model.dart';

import '../../common/common_network_image.dart';
import '../../common/common_text_field.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_text_style.dart';

import '../widget/region_picker_sheet.dart';
import 'meet_create_controller.dart';
import 'meet_create_state.dart';

const workList = [
  '헬스','클라이밍','볼링','테니스','스쿼시','배드민턴','런닝','사이클','풋살/축구','수영','다이어트','골프',
  '필라테스','요가','탁구','당구','복싱','주짓수','보드','기타',
];

class MeetCreateStepperView extends ConsumerStatefulWidget {
  const MeetCreateStepperView({super.key, this.meetId});

  final String? meetId; // ✅ null이면 생성, 있으면 수정

  @override
  ConsumerState<MeetCreateStepperView> createState() => _MeetCreateStepperViewState();
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

    // ✅ 수정모드 최초 1회 initForEdit
    if (!_initedEdit && widget.meetId != null) {
      _initedEdit = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await controller.initForEdit(widget.meetId!);
        _syncTextControllersFromState();
      });
    }

    // 수정 state 로딩 완료 후에도 동기화(필요 시)
    // (가끔 initForEdit 이후에도 build 타이밍 때문에 한 번 더 보정)
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
          icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.icDefault),
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
                    Navigator.pop(context, true); // ✅ 목록 리프레시용
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
                    state.isLast ? (state.isEdit ? '수정 완료' : '생성 완료') : '다음',
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
                  .map((w) => CommonChip(
                label: w,
                selected: state.category == w,
                onTap: () => controller.selectCategory(w),
              ))
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
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.bgSecondary,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.borderSecondary),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.search, size: 18, color: AppColors.icSecondary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '동/읍/면 검색해서 추가하기',
                        style: AppTextStyle.bodyMediumStyle.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: AppColors.icDisabled),
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
                    .map((r) => _SelectedRegionChip(
                  label: r.fullName,
                  onDelete: () => controller.removeRegion(r.code),
                ))
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
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                    activeColor: AppColors.sky400,
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
            Text('썸네일 등록', style: AppTextStyle.titleSmallBoldStyle),
            const SizedBox(height: 10),
            _ThumbPicker(
              thumbnail: state.thumbnail,
              existingUrl: state.existingThumbnailUrl,
              removeExisting: state.removeExistingThumbnail,
              onPick: controller.pickThumbnail,
              onRemove: controller.removeThumbnail,
            ),
          ],
        );

      default:
        return const SizedBox.shrink();
    }
  }
}

class _ThumbPicker extends StatelessWidget {
  const _ThumbPicker({
    required this.thumbnail,
    required this.existingUrl,
    required this.removeExisting,
    required this.onPick,
    required this.onRemove,
  });

  final XFile? thumbnail;
  final String? existingUrl;
  final bool removeExisting;

  final VoidCallback onPick;
  final VoidCallback onRemove;

  bool get hasExisting => existingUrl != null && !removeExisting;
  bool get hasLocal => thumbnail != null;
  bool get hasAny => hasLocal || hasExisting;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPick,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 180,
        decoration: BoxDecoration(
          color: AppColors.bgSecondary,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.borderSecondary),
        ),
        child: Stack(
          children: [
            if (!hasAny)
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.image_outlined, color: AppColors.icSecondary, size: 28),
                    const SizedBox(height: 8),
                    Text(
                      '썸네일 선택하기',
                      style: AppTextStyle.labelMediumStyle.copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              )
            else
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: _buildImage(),
              ),
            if (hasAny)
              Positioned(
                top: 10,
                right: 10,
                child: InkWell(
                  onTap: onRemove,
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.35),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Icon(Icons.close, color: Colors.white, size: 18),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildImage() {
    if (thumbnail != null) {
      return Image.file(
        File(thumbnail!.path),
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.cover,
      );
    }

    // ✅ 공통 위젯 사용(너가 원한 방식)
    return CommonNetworkImage(
      imageUrl: existingUrl!,
      width: double.infinity,
      height: 180,
      fit: BoxFit.cover,
    );
  }
}

// --- 공통 스타일 위젯들(간단) ---
class _StepIndicator extends StatelessWidget {
  const _StepIndicator({required this.step, required this.total});
  final int step;
  final int total;

  @override
  Widget build(BuildContext context) {
    final progress = (step + 1) / total;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Column(
        children: [
          Row(
            children: [
              Text('STEP ${step + 1}/$total',
                  style: AppTextStyle.labelSmallStyle.copyWith(color: AppColors.textSecondary)),
              const Spacer(),
              Text('${(progress * 100).round()}%',
                  style: AppTextStyle.labelSmallStyle.copyWith(color: AppColors.textTeritary)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
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

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? AppColors.sky50 : AppColors.bgWhite,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? AppColors.borderPrimary : AppColors.borderSecondary,
          ),
        ),
        child: Text(
          label,
          style: AppTextStyle.labelSmallStyle.copyWith(
            color: selected ? AppColors.textPrimary : AppColors.textSecondary,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _SelectedRegionChip extends StatelessWidget {
  const _SelectedRegionChip({required this.label, required this.onDelete});
  final String label;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.sky50,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.borderPrimary),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.place, size: 14, color: AppColors.icPrimary),
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 220),
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyle.labelSmallStyle.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 6),
          InkWell(
            onTap: onDelete,
            borderRadius: BorderRadius.circular(999),
            child: const Padding(
              padding: EdgeInsets.all(2),
              child: Icon(Icons.close, size: 16, color: AppColors.icPrimary),
            ),
          ),
        ],
      ),
    );
  }
}
