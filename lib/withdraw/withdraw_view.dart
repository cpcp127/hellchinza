import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../common/common_bottom_button.dart';
import '../constants/app_colors.dart';
import '../constants/app_text_style.dart';
import 'withdraw_controller.dart';
import 'withdraw_state.dart';

class WithdrawView extends ConsumerWidget {
  const WithdrawView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(withdrawControllerProvider);
    final controller = ref.read(withdrawControllerProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.bgWhite,
      appBar: AppBar(
        backgroundColor: AppColors.bgWhite,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            size: 20,
            color: AppColors.icDefault,
          ),
          onPressed: () {
            if (state.step == WithdrawStep.detail) {
              controller.goBack();
              return;
            }
            Navigator.pop(context);
          },
        ),
        title: Text('회원 탈퇴', style: AppTextStyle.titleMediumBoldStyle),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => FocusScope.of(context).unfocus(),
                behavior: HitTestBehavior.translucent,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  child: state.step == WithdrawStep.reason
                      ? _WithdrawReasonStep(
                          reasons: controller.reasons,
                          selectedReason: state.selectedReason,
                          errorMessage: state.errorMessage,
                          onSelect: controller.selectReason,
                        )
                      : _WithdrawDetailStep(
                          controller: state.detailController,
                          selectedReason: state.selectedReason ?? '',
                          errorMessage: state.errorMessage,
                        ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: CommonBottomButton(
                title: state.step == WithdrawStep.reason ? '다음' : '탈퇴하기',
                enabled: state.step == WithdrawStep.reason
                    ? state.canGoNext
                    : state.canWithdraw,
                loading: state.isLoading,
                onTap: () {
                  if (state.step == WithdrawStep.reason) {
                    controller.goNext();
                  } else {
                    controller.submitWithdraw(context);
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WithdrawReasonStep extends StatelessWidget {
  const _WithdrawReasonStep({
    required this.reasons,
    required this.selectedReason,
    required this.onSelect,
    this.errorMessage,
  });

  final List<String> reasons;
  final String? selectedReason;
  final String? errorMessage;
  final void Function(String reason) onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text('탈퇴하시는 이유를 알려주세요', style: AppTextStyle.headlineSmallBoldStyle),
        const SizedBox(height: 8),
        Text(
          '더 나은 서비스를 위해 참고할게요.',
          style: AppTextStyle.bodyMediumStyle.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 24),
        ...reasons.map(
          (reason) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _WithdrawReasonTile(
              title: reason,
              selected: selectedReason == reason,
              onTap: () => onSelect(reason),
            ),
          ),
        ),
        if (errorMessage != null) ...[
          const SizedBox(height: 8),
          Text(
            errorMessage!,
            style: AppTextStyle.bodySmallStyle.copyWith(
              color: AppColors.textError,
            ),
          ),
        ],
      ],
    );
  }
}

class _WithdrawReasonTile extends StatelessWidget {
  const _WithdrawReasonTile({
    required this.title,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.bgWhite,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? AppColors.borderPrimary
                : AppColors.borderSecondary,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: AppTextStyle.bodyMediumStyle.copyWith(
                  color: AppColors.textDefault,
                ),
              ),
            ),
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected
                      ? AppColors.borderPrimary
                      : AppColors.borderSecondary,
                  width: 1.5,
                ),
                color: AppColors.bgWhite,
              ),
              child: Center(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  width: selected ? 10 : 0,
                  height: selected ? 10 : 0,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.icPrimary,
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
class _WithdrawDetailStep extends StatelessWidget {
  const _WithdrawDetailStep({
    required this.controller,
    required this.selectedReason,
    this.errorMessage,
  });

  final TextEditingController controller;
  final String selectedReason;
  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text(
          '추가로 남기고 싶은 말이 있나요?',
          style: AppTextStyle.headlineSmallBoldStyle,
        ),
        const SizedBox(height: 8),
        Text(
          '선택한 이유: $selectedReason',
          style: AppTextStyle.bodyMediumStyle.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '선택사항이라 입력하지 않아도 탈퇴할 수 있어요.',
          style: AppTextStyle.bodySmallStyle.copyWith(
            color: AppColors.textTeritary,
          ),
        ),
        const SizedBox(height: 24),
        Container(
          decoration: BoxDecoration(
            color: AppColors.bgWhite,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppColors.borderSecondary,
            ),
          ),
          child: TextField(
            controller: controller,
            maxLines: 7,
            minLines: 7,
            maxLength: 300,
            style: AppTextStyle.bodyMediumStyle,
            decoration: InputDecoration(
              hintText: '불편했던 점이나 개선되었으면 하는 점을 자유롭게 적어주세요.',
              hintStyle: AppTextStyle.bodyMediumStyle.copyWith(
                color: AppColors.textLabel,
              ),
              border: InputBorder.none,
              counterStyle: AppTextStyle.bodySmallStyle.copyWith(
                color: AppColors.textLabel,
              ),
              contentPadding: const EdgeInsets.all(16),
            ),
          ),
        ),
        if (errorMessage != null) ...[
          const SizedBox(height: 8),
          Text(
            errorMessage!,
            style: AppTextStyle.bodySmallStyle.copyWith(
              color: AppColors.textError,
            ),
          ),
        ],
      ],
    );
  }
}