import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hellchinza/claim/presentation/claim_controller.dart';
import 'package:hellchinza/claim/providers/claim_provider.dart';
import 'package:hellchinza/common/common_chip.dart';
import 'package:hellchinza/common/common_text_field.dart';

import '../../../constants/app_colors.dart';
import '../../../constants/app_text_style.dart';
import '../../../services/snackbar_service.dart';

import '../domain/claim_model.dart';

class ClaimView extends ConsumerStatefulWidget {
  const ClaimView({super.key, required this.target});

  final ClaimTarget target;

  @override
  ConsumerState<ClaimView> createState() => _ClaimViewState();
}

class _ClaimViewState extends ConsumerState<ClaimView> {
  late final TextEditingController textEditingController;

  @override
  void initState() {
    super.initState();
    textEditingController = TextEditingController();
  }

  @override
  void dispose() {
    textEditingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(claimControllerProvider(widget.target));
    final controller = ref.read(
      claimControllerProvider(widget.target).notifier,
    );

    return Scaffold(
      backgroundColor: AppColors.bgWhite,
      appBar: AppBar(
        title: Text(
          '${widget.target.type.label} 신고',
          style: AppTextStyle.titleMediumBoldStyle,
        ),
        backgroundColor: AppColors.bgWhite,
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  _TargetHeader(target: widget.target),
                  const SizedBox(height: 14),
                  Text('사유 선택', style: AppTextStyle.titleSmallBoldStyle),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: ClaimController.reasonPool.map((reason) {
                      final selected = state.selectedReasons.contains(reason);

                      return CommonChip(
                        label: reason,
                        selected: selected,
                        onTap: () => controller.toggleReason(reason),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  Text('추가 설명 (선택)', style: AppTextStyle.titleSmallBoldStyle),
                  const SizedBox(height: 10),
                  CommonTextField(
                    minLines: 4,
                    maxLines: 8,
                    onChanged: controller.setDetail,
                    controller: textEditingController,
                    scrollPadding: 300,
                    hintText: '상세 내용을 적어주세요 (선택)',
                  ),
                  if (state.errorMessage != null &&
                      state.errorMessage!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      state.errorMessage!,
                      style: AppTextStyle.bodySmallStyle.copyWith(
                        color: AppColors.textError,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                height: 52,
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: state.canSubmit
                      ? () async {
                          try {
                            await controller.submit();
                            SnackbarService.show(
                              type: AppSnackType.success,
                              message: '신고가 접수되었습니다',
                            );
                            if (context.mounted) {
                              Navigator.pop(context, true);
                            }
                          } catch (_) {
                            SnackbarService.show(
                              type: AppSnackType.error,
                              message: '신고 실패',
                            );
                          }
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.btnPrimary,
                    disabledBackgroundColor: AppColors.btnDisabled,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    state.isLoading ? '접수 중…' : '신고하기',
                    style: AppTextStyle.labelLargeStyle.copyWith(
                      color: AppColors.white,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _TargetHeader extends StatelessWidget {
  const _TargetHeader({required this.target});

  final ClaimTarget target;

  @override
  Widget build(BuildContext context) {
    final title = target.title ?? '${target.type.label} (${target.targetId})';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bgSecondary,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderSecondary),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.sky50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.borderPrimary),
            ),
            child: Icon(switch (target.type) {
              ClaimTargetType.feed => Icons.feed_outlined,
              ClaimTargetType.meet => Icons.groups_outlined,
              ClaimTargetType.user => Icons.person_outline,
              ClaimTargetType.comment => Icons.comment_outlined,
            }, color: AppColors.icPrimary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${target.type.label} 신고 대상',
                  style: AppTextStyle.labelSmallStyle.copyWith(
                    color: AppColors.textTeritary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyle.titleSmallBoldStyle.copyWith(
                    color: AppColors.textDefault,
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
