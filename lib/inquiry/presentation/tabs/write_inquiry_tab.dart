import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:hellchinza/common/common_text_field.dart';
import 'package:hellchinza/constants/app_colors.dart';
import 'package:hellchinza/constants/app_text_style.dart';
import 'package:hellchinza/inquiry/providers/inquiry_provider.dart';
import 'package:hellchinza/services/dialog_service.dart';
import 'package:hellchinza/services/image_service.dart';
import 'package:hellchinza/services/snackbar_service.dart';

class WriteInquiryTab extends ConsumerStatefulWidget {
  const WriteInquiryTab({
    super.key,
    required this.controller,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final VoidCallback onSubmitted;

  @override
  ConsumerState<WriteInquiryTab> createState() => _WriteInquiryTabState();
}

class _WriteInquiryTabState extends ConsumerState<WriteInquiryTab> {
  XFile? _picked;

  bool get _canSubmit {
    final isSubmitting = ref.read(inquiryControllerProvider).isSubmitting;
    return widget.controller.text.trim().isNotEmpty && !isSubmitting;
  }

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _pickImage() async {
    final x = await ImageService().showImagePicker(context);
    if (x == null || !mounted) return;

    final webpImage = await ImageService().convertToWebp(File(x.path));
    if (!mounted) return;

    setState(() => _picked = webpImage);
  }

  Future<void> _submit() async {
    final text = widget.controller.text.trim();
    if (text.isEmpty) return;

    final ok = await DialogService.showConfirm(
      context: context,
      title: '문의 제출',
      message: '문의 내용을 제출할까요?',
      confirmText: '제출',
    );
    if (ok != true) return;

    try {
      await ref
          .read(inquiryControllerProvider.notifier)
          .submit(message: text, image: _picked);

      widget.controller.clear();

      if (mounted) {
        setState(() => _picked = null);
      }

      SnackbarService.show(type: AppSnackType.success, message: '문의가 접수되었습니다');

      widget.onSubmitted();
    } catch (e) {
      SnackbarService.show(type: AppSnackType.error, message: '문의 접수에 실패했어요');
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(inquiryControllerProvider);

    return Scaffold(
      bottomNavigationBar: _buildSubmitButton(state.isSubmitting),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '문의 내용을 입력해주세요',
                style: AppTextStyle.titleSmallBoldStyle.copyWith(
                  color: AppColors.textDefault,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '불편한 점이나 제안 사항을 남겨주시면\n빠르게 확인할게요 🙂',
                style: AppTextStyle.bodySmallStyle.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.bgWhite,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.borderSecondary),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          '사진 첨부(선택)',
                          style: AppTextStyle.labelMediumStyle.copyWith(
                            color: AppColors.textDefault,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap: state.isSubmitting ? null : _pickImage,
                          child: Row(
                            children: [
                              const Icon(
                                Icons.image_outlined,
                                size: 18,
                                color: AppColors.icDefault,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _picked == null ? '추가' : '변경',
                                style: AppTextStyle.labelMediumStyle.copyWith(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (_picked != null) ...[
                      const SizedBox(height: 10),
                      Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: Image.file(
                              File(_picked!.path),
                              width: double.infinity,
                              height: 180,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: GestureDetector(
                              onTap: state.isSubmitting
                                  ? null
                                  : () => setState(() => _picked = null),
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: AppColors.black.withOpacity(0.45),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: const Icon(
                                  Icons.close,
                                  size: 18,
                                  color: AppColors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.bgWhite,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.borderSecondary),
                ),
                child: CommonTextField(
                  controller: widget.controller,
                  hintText: '예) 모임 채팅이 안 열려요 / 피드가 안 올라가요 등',
                  maxLines: 6,
                  minLines: 4,
                  onChanged: (_) {},
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSubmitButton(bool isSubmitting) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SizedBox(
        width: double.infinity,
        height: 48,
        child: ElevatedButton(
          onPressed: _canSubmit ? _submit : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.btnPrimary,
            disabledBackgroundColor: AppColors.btnDisabled,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            elevation: 0,
          ),
          child: isSubmitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(
                  '문의 제출',
                  style: AppTextStyle.labelLargeStyle.copyWith(
                    color: AppColors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
        ),
      ),
    );
  }
}
