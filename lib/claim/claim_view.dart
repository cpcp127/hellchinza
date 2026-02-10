import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hellchinza/common/common_chip.dart';
import 'package:hellchinza/common/common_text_field.dart';

import '../../services/snackbar_service.dart'; // 너꺼 경로에 맞춰

import '../constants/app_colors.dart';
import '../constants/app_text_style.dart';
import 'claim_controller.dart';
import 'domain/claim_model.dart';

class ClaimView extends ConsumerWidget {
  ClaimView({super.key, required this.target});

  final ClaimTarget target;
  TextEditingController textEditingController = TextEditingController();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(claimControllerProvider(target));
    final controller = ref.read(claimControllerProvider(target).notifier);

    return Scaffold(
      backgroundColor: AppColors.bgWhite,
      appBar: AppBar(
        title: Text(
          '${target.type.label} 신고',
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
                  _TargetHeader(target: target),
                  const SizedBox(height: 14),

                  Text('사유 선택', style: AppTextStyle.titleSmallBoldStyle),
                  const SizedBox(height: 10),

                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: ClaimController.reasonPool.map((r) {
                      final selected = state.selectedReasons.contains(r);

                      return CommonChip(
                        label: r,
                        selected: selected,
                        onTap: () => controller.toggleReason(r),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 16),

                  Text('추가 설명 (선택)', style: AppTextStyle.titleSmallBoldStyle),
                  const SizedBox(height: 10),

                  // 너가 쓰는 CommonTextField가 있으면 그걸로 교체
                  CommonTextField(
                    minLines: 4,
                    maxLines: 8,
                    onChanged: controller.setDetail,
                    controller: textEditingController,
                    scrollPadding: 300,
                    hintText: '상세 내용을 적어주세요 (선택)',
                  ),

                  if (state.errorMessage != null) ...[
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
                            await controller.submit(
                              reporterUid:
                                  FirebaseAuth.instance.currentUser!.uid,
                            );
                            SnackbarService.show(
                              type: AppSnackType.success,
                              message: '신고가 접수되었습니다',
                            );
                            Navigator.pop(context, true);
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
            SizedBox(height: 16),
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

// class _ReasonChip extends StatelessWidget {
//   const _ReasonChip({
//     required this.label,
//     required this.selected,
//     required this.onTap,
//   });
//
//   final String label;
//   final bool selected;
//   final VoidCallback onTap;
//
//   @override
//   Widget build(BuildContext context) {
//     return InkWell(
//       onTap: onTap,
//       borderRadius: BorderRadius.circular(999),
//       child: Container(
//         padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
//         decoration: BoxDecoration(
//           color: selected ? AppColors.sky50 : AppColors.bgWhite,
//           borderRadius: BorderRadius.circular(999),
//           border: Border.all(
//             color: selected ? AppColors.borderPrimary : AppColors.borderSecondary,
//           ),
//         ),
//         child: Text(
//           label,
//           style: AppTextStyle.labelSmallStyle.copyWith(
//             color: selected ? AppColors.textPrimary : AppColors.textSecondary,
//             fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
//           ),
//         ),
//       ),
//     );
//   }
// }
