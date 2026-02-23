import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:hellchinza/services/image_service.dart';

import '../common/common_text_field.dart';
import '../constants/app_colors.dart';
import '../constants/app_text_style.dart';
import '../services/dialog_service.dart';
import '../services/snackbar_service.dart';

class WriteInquiryTab extends StatefulWidget {
  const WriteInquiryTab({
    required this.uid,
    required this.controller,
    required this.onSubmitted,
  });

  final String uid;
  final TextEditingController controller;
  final VoidCallback onSubmitted; // 제출 성공 후 탭 이동 등

  @override
  State<WriteInquiryTab> createState() => _WriteInquiryTabState();
}

class _WriteInquiryTabState extends State<WriteInquiryTab> {
  XFile? _picked;
  bool _isSubmitting = false;

  bool get _canSubmit => widget.controller.text.trim().isNotEmpty && !_isSubmitting;

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
    // 버튼 활성/비활성 갱신
    if (mounted) setState(() {});
  }

  Future<void> _pickImage() async {

    final x =await ImageService().showImagePicker();
    if (!mounted) return;
    setState(() => _picked = x);
  }

  Future<String?> _uploadInquiryImage({
    required String inquiryId,
    required XFile file,
  }) async {
    final ref = FirebaseStorage.instance
        .ref()
        .child('inquiries')
        .child(widget.uid)
        .child('$inquiryId.webp');

    // XFile -> File
    final f = File(file.path);
    final task = await ref.putFile(
      f,
      SettableMetadata(contentType: 'image/webp'),
    );
    return task.ref.getDownloadURL();
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

    setState(() => _isSubmitting = true);

    try {
      final db = FirebaseFirestore.instance;
      final docRef = db.collection('inquiries').doc(); // id 먼저 생성

      String? imageUrl;
      if (_picked != null) {
        imageUrl = await _uploadInquiryImage(
          inquiryId: docRef.id,
          file: _picked!,
        );
      }

      await docRef.set({
        'id': docRef.id,
        'authorUid': widget.uid,
        'message': text,
        'status': 'open',
        // 사진(선택)
        'imageUrls': imageUrl == null ? [] : [imageUrl],
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'answer':'',

      });

      widget.controller.clear();
      setState(() {
        _picked = null;
        _isSubmitting = false;
      });

      SnackbarService.show(
        type: AppSnackType.success,
        message: '문의가 접수되었습니다',
      );

      widget.onSubmitted();
    } catch (e) {
      setState(() => _isSubmitting = false);
      SnackbarService.show(
        type: AppSnackType.error,
        message: '문의 접수에 실패했어요',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
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

          // ✅ 첨부 영역(선택)
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
                      onTap: _isSubmitting ? null : _pickImage,
                      child: Row(
                        children: [
                          const Icon(Icons.image_outlined, size: 18, color: AppColors.icDefault),
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
                          onTap: _isSubmitting
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

          // ✅ 텍스트 입력
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

          const Spacer(),

          // ✅ 제출 버튼: 텍스트 없으면 비활성화
          SizedBox(
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
              child: _isSubmitting
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
        ],
      ),
    );
  }
}