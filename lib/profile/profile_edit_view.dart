import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hellchinza/auth/domain/user_model.dart';
import 'package:hellchinza/auth/providers/user_provider.dart';
import 'package:hellchinza/common/common_back_appbar.dart';
import 'package:hellchinza/common/common_chip.dart';
import 'package:hellchinza/common/common_text_field.dart';
import 'package:hellchinza/constants/app_colors.dart';
import 'package:hellchinza/constants/app_constants.dart';
import 'package:hellchinza/constants/app_text_style.dart';
import 'package:hellchinza/home/providers/home_provider.dart';
import 'package:hellchinza/profile/providers/profile_provider.dart';
import 'package:hellchinza/services/image_service.dart';

class ProfileEditView extends ConsumerStatefulWidget {
  const ProfileEditView({super.key});

  @override
  ConsumerState<ProfileEditView> createState() => _ProfileEditViewState();
}

class _ProfileEditViewState extends ConsumerState<ProfileEditView> {
  late final TextEditingController _nickCtrl;
  late final TextEditingController _descCtrl;

  List<String> _selected = [];
  bool _saving = false;
  XFile? selectImage;
  bool deletePhoto = false;

  @override
  void initState() {
    super.initState();

    final my = ref.read(myUserModelProvider);
    _nickCtrl = TextEditingController(text: my.nickname);
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
      await ref.read(profileRepoProvider).saveProfile(
        selectedImage: selectImage,
        nickname: _nickCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        category: _selected,
        deletePhoto: deletePhoto,
      );

      final uid = ref.read(profileRepoProvider).currentUid!;
      final userModel = await ref.read(homeRepoProvider).fetchUser(uid);

      if (userModel != null) {
        ref.read(myUserModelProvider.notifier).updateUserModel(userModel);
        ref.read(userRepoProvider).clear(userModel.uid);
        ref.invalidate(userMiniProvider(userModel.uid));
      }

      if (!mounted) return;
      Navigator.pop(context);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _saving = false);
    }
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
    return nick.isNotEmpty && _selected.isNotEmpty && !_saving;
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
              _ProfileTopCard(
                selectedImage: selectImage,
                photoUrl: networkUrlToShow(my),
                onTapPhoto: () {
                  FocusManager.instance.primaryFocus?.unfocus();

                  ImageService().showProfileImageActionSheet(
                    context: context,
                    hasImage: true,
                    onCamera: () async {
                      final imageFile = await ImageService().takePicture(context);
                      if (imageFile == null) return;
                      final webpImage = await ImageService().convertToWebp(
                        File(imageFile.path),
                      );

                      setState(() {
                        selectImage = webpImage;
                        deletePhoto = false;
                      });
                    },
                    onGallery: () async {
                      final imageFile = await ImageService().showImagePicker(context);
                      if (imageFile == null) return;
                      final webpImage = await ImageService().convertToWebp(
                        File(imageFile.path),
                      );

                      setState(() {
                        selectImage = webpImage;
                        deletePhoto = false;
                      });
                    },
                    onDelete: () {
                      setState(() {
                        selectImage = null;
                        deletePhoto = true;
                      });
                    },
                  );
                },
              ),
              const SizedBox(height: 16),
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
                          if (value == null || value.trim().isEmpty) return '';
                          if (RegExp(r'\s').hasMatch(value)) return '';
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
                        onTap: _toggleCategory,
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
  final String? photoUrl;
  final XFile? selectedImage;
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
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: child,
        ),
      ),
    );
  }
}