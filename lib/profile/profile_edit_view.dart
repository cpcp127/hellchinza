import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hellchinza/common/common_chip.dart';
import 'package:hellchinza/constants/app_constants.dart';
import 'package:hellchinza/services/image_service.dart';
import 'package:hellchinza/services/storage_upload_service.dart';

import '../auth/domain/user_model.dart';
import '../common/common_back_appbar.dart';
import '../common/common_bottom_button.dart';
import '../common/common_text_field.dart';
import '../constants/app_colors.dart';
import '../constants/app_text_style.dart';
import '../home/home_controller.dart';

class ProfileEditView extends ConsumerStatefulWidget {
  const ProfileEditView({super.key});

  @override
  ConsumerState<ProfileEditView> createState() => _ProfileEditViewState();
}

class _ProfileEditViewState extends ConsumerState<ProfileEditView> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nickCtrl;
  late final TextEditingController _descCtrl;

  List<String> _selected = [];
  bool _saving = false;
  XFile? selectImage;
  bool deletePhoto = false;
  @override
  void initState() {
    super.initState();

    // 전역 유저 모델
    final my = ref.read(myUserModelProvider);

    _nickCtrl = TextEditingController(text: my.nickname ?? '');
    _descCtrl = TextEditingController(text: my.description ?? '');
    _selected = List<String>.from(my.category);
  }

  @override
  void dispose() {
    _nickCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await saveProfile(
        selectedImage: selectImage,
        nickname: _nickCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        category: _selected,deletePhoto: deletePhoto
      );
      UserModel? userModel = await ref
          .read(homeControllerProvider.notifier)
          .fetchUser(FirebaseAuth.instance.currentUser!.uid);
      ref.read(myUserModelProvider.notifier).updateUserModel(userModel!);

      Navigator.pop(context);
    } catch (e) {
      // TODO: 스낵바/토스트
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> saveProfile({
    required XFile? selectedImage,
    required String nickname,
    required String description,
    required List<String> category,
    required bool deletePhoto,
  }) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final userRef = FirebaseFirestore.instance.collection('users').doc(uid);
    final snap = await userRef.get();
    final prevPath = snap.data()?['photoPath'] as String?;
    UploadResult? uploaded;

    if (selectedImage != null) {
      uploaded = await const StorageUploadService().uploadProfileImage(
        uid: uid,
        file: selectedImage,
      );
    }

    final data = <String, dynamic>{
      'nickname': nickname,
      'description': description,
      'category': category,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    // 3) 삭제 요청이면 photoUrl/photoPath null
    if (deletePhoto) {
      data['photoUrl'] = null;
      data['photoPath'] = null;
    }

    if (uploaded != null) {
      data['photoUrl'] = uploaded.url;
      data['photoPath'] = uploaded.path; // ✅ 추가
    }

    await userRef.set(data, SetOptions(merge: true));
    // 5) Storage 이전 파일 삭제 조건
    // - 새 이미지 업로드했다면 이전 파일 삭제
    // - deletePhoto=true면 이전 파일 삭제
    final shouldDeletePrev = (uploaded != null) || deletePhoto;

    if (shouldDeletePrev && prevPath != null && prevPath.isNotEmpty) {
      try {
        await FirebaseStorage.instance.ref(prevPath).delete();
      } catch (_) {
        // 삭제 실패해도 앱 흐름은 유지
      }}
  }

  void _toggleCategory(String c) {
    setState(() {
      if (_selected.contains(c)) {
        _selected.remove(c);
      } else {
        _selected.add(c);
      }
    });
  }

  bool get _isValid {
    final nick = _nickCtrl.text.trim();

    return nick.isNotEmpty &&
        _selected.isNotEmpty && // ⭐ 관심 카테고리 1개 이상
        !_saving;
  }
  String? networkUrlToShow(UserModel my) {
    if (selectImage != null) return null;
    if (deletePhoto) return null;
    final url = (my.photoUrl ?? '').trim();
    return url.isEmpty ? null : url;
  }
  @override
  Widget build(BuildContext context) {
    final my = ref.watch(myUserModelProvider);
    final hasNetworkPhoto = (my.photoUrl ?? '').trim().isNotEmpty;
    final hasSelected = selectImage != null;
    return Scaffold(
      backgroundColor: AppColors.bgWhite,
      appBar: CommonBackAppbar(
        title: '프로필 편집',
        actions: [
          GestureDetector(
            onTap: _isValid ? _save : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: _saving
                    ? const CupertinoActivityIndicator()
                    : Text(
                        '저장',
                        style: AppTextStyle.titleSmallBoldStyle.copyWith(
                          color: _isValid
                              ? AppColors.textPrimary
                              : AppColors.textDisabled,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(top: 16, bottom: 24),
          child: Column(
            children: [
              // 1) 프로필 이미지 카드
              _ProfileTopCard(
                // ✅ 선택된 이미지가 있으면 그것을 우선으로 보여줌
                selectedImage: selectImage,
                // ✅ 선택된 이미지가 없으면 기존 photoUrl 보여줌
                photoUrl: networkUrlToShow(my),

                onTapPhoto: () {
                  FocusManager.instance.primaryFocus?.unfocus();

                  ImageService().showProfileImageActionSheet(
                    context: context,
                    hasImage: true,
                    onCamera: () async {
                      XFile? imageFile = await ImageService().takePicture();
                      if (imageFile == null) return;
                      setState(() {
                        selectImage = imageFile;
                        deletePhoto = false; // 새 이미지 선택하면 삭제 예약 해제
                      });
                    },
                    onGallery: () async {
                      XFile? imageFile = await ImageService().showImagePicker();
                      if (imageFile == null) return;
                      setState(() {
                        selectImage = imageFile;
                        deletePhoto = false; // 새 이미지 선택하면 삭제 예약 해제
                      });
                    },
                    onDelete: () {
                      setState(() {
                        selectImage = null;
                        deletePhoto = true;   // 기존 네트워크 이미지도 삭제 예약
                      });
                    },
                  );
                },
              ),

              const SizedBox(height: 16),

              // 2) 입력 폼 카드 (닉네임/소개)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _Card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '닉네임',
                        style: AppTextStyle.titleMediumBoldStyle.copyWith(
                          color: AppColors.textDefault,
                        ),
                      ),
                      const SizedBox(height: 12),
                      CommonTextField(
                        hintText: '닉네임을 입력하세요',
                        maxLength: 8,
                        controller: _nickCtrl,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return ''; // 에러텍스트 숨기는 방식이면 '' 유지
                          }
                          if (RegExp(r'\s').hasMatch(value)) {
                            return '';
                          }
                          return null;
                        },
                        onChanged: (_) => setState(() {}),
                      ),

                      const SizedBox(height: 14),

                      Text(
                        '소개',
                        style: AppTextStyle.titleMediumBoldStyle.copyWith(
                          color: AppColors.textDefault,
                        ),
                      ),
                      const SizedBox(height: 12),
                      CommonTextField(
                        hintText: '소개를 입력해 주세요.',
                        minLines: 4,
                        maxLines: 6,
                        maxLength: 80,
                        controller: _descCtrl,
                        onChanged: (_) => setState(() {}),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // 3) 카테고리 카드
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _Card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '관심 카테고리',
                        style: AppTextStyle.titleMediumBoldStyle.copyWith(
                          color: AppColors.textDefault,
                        ),
                      ),
                      const SizedBox(height: 12),
                      CommonChipWrap(
                        items: workList,
                        selectedItems: _selected,
                        onTap: (str) {
                          _toggleCategory(str);
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileTopCard extends StatelessWidget {
  final String? photoUrl; // 기존 네트워크 이미지
  final XFile? selectedImage; // 새로 선택된 이미지
  final VoidCallback onTapPhoto;

  const _ProfileTopCard({
    required this.photoUrl,
    required this.selectedImage,
    required this.onTapPhoto,
  });

  @override
  Widget build(BuildContext context) {
    final hasSelected = selectedImage != null;
    final hasNetwork = (photoUrl ?? '').trim().isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.bgWhite,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.borderSecondary),
          boxShadow: [
            BoxShadow(
              color: AppColors.black.withOpacity(0.04),
              offset: const Offset(0, 2),
              blurRadius: 8,
            ),
            BoxShadow(
              color: AppColors.black.withOpacity(0.02),
              offset: const Offset(0, 6),
              blurRadius: 20,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '프로필 이미지',
                  style: AppTextStyle.titleMediumBoldStyle.copyWith(
                    color: AppColors.textDefault,
                  ),
                ),
                const SizedBox(height: 12),
                Center(
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: Container(
                          width: 104,
                          height: 104,
                          color: AppColors.gray100,
                          child: hasSelected
                              ? Image.file(
                                  File(selectedImage!.path),
                                  fit: BoxFit.cover,
                                )
                              : hasNetwork
                              ? Image.network(photoUrl!, fit: BoxFit.cover)
                              : Icon(
                                  Icons.person,
                                  size: 44,
                                  color: AppColors.icSecondary,
                                ),
                        ),
                      ),

                      Positioned(
                        right: -2,
                        bottom: -2,
                        child: GestureDetector(
                          onTap: onTapPhoto,
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: AppColors.btnPrimary,
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: AppColors.white,
                                width: 2,
                              ),
                            ),
                            child: Icon(
                              Icons.camera_alt,
                              size: 18,
                              color: AppColors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 공통 카드(흰색 + 보더 + 그림자)
class _Card extends StatelessWidget {
  final Widget child;

  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.bgWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderSecondary),
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withOpacity(0.04),
            offset: const Offset(0, 2),
            blurRadius: 8,
          ),
          BoxShadow(
            color: AppColors.black.withOpacity(0.02),
            offset: const Offset(0, 6),
            blurRadius: 20,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Padding(padding: const EdgeInsets.all(16), child: child),
      ),
    );
  }
}
