import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';

import '../common/common_action_sheet.dart';

class ImageService {
  ImageService();

  ImagePicker imagePicker = ImagePicker();

  /// chatGpt
  /// 프로필 : 512 x 512, 70
  /// 피드 : 1080 x 1080, 80
  /// 스토리/라이브 썸네일 : 720 x 720, 70

  Future<XFile?> showImagePicker() async {
    final picked = await imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 100,

    );
    if (picked == null) return null;

    return await _convertToWebp(File(picked.path));
  }

  Future<List<XFile>?> showMultiImagePicker(int? limit) async {
    final picks =   await imagePicker.pickMultiImage(
      imageQuality: 100,

      limit: limit ?? 10,
    );
    if (picks == null) return null;

    List<XFile> result = [];
    for (final img in picks) {
      final webp = await _convertToWebp(File(img.path));
      result.add(webp);
    }

    return result;
  }



  /// 카메라에서 이미지 촬영
  Future<XFile?> takePicture() async {
    final picked = await imagePicker.pickImage(
      source: ImageSource.camera,
      imageQuality: 100,

    );
    if (picked == null) return null;

    return await _convertToWebp(File(picked.path));
  }

  Future<XFile> _convertToWebp(File file) async {
    final targetPath = file.path + '_webp.webp';

    final result = await FlutterImageCompress.compressAndGetFile(
      file.path,
      targetPath,
      quality: 80,
      keepExif: false,
      autoCorrectionAngle: true, // 회전 자동 보정
      format: CompressFormat.webp, // WebP 변환
    );

    return XFile(result!.path);
  }

  Future<void> showProfileImageActionSheet({
    required BuildContext context,
    required bool hasImage,
    required VoidCallback onCamera,
    required VoidCallback onGallery,
    required VoidCallback onDelete,
  }) async {
    final items = <CommonActionSheetItem>[
      CommonActionSheetItem(
        icon: Icons.photo_camera,
        title: '카메라로 촬영하기',
        onTap: onCamera,
      ),
      CommonActionSheetItem(
        icon: Icons.photo_library,
        title: '앨범에서 선택하기',
        onTap: onGallery,
      ),
      if (hasImage)
        CommonActionSheetItem(
          icon: Icons.delete_outline,
          title: '이미지 삭제하기',
          onTap: onDelete,
          isDestructive: true,
        ),
    ];

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => CommonActionSheet(
        title: '프로필 이미지',
        items: items,
      ),
    );
  }
}

