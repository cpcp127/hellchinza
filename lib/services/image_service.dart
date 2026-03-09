import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import '../common/common_action_sheet.dart';

class ImageService {
  ImageService();

  final ImagePicker imagePicker = ImagePicker();

  /// chatGpt
  /// 프로필 : 512 x 512, 70
  /// 피드 : 1080 x 1080, 80
  /// 스토리/라이브 썸네일 : 720 x 720, 70

  Future<XFile?> showImagePicker(BuildContext context) async {
    final ok = await _ensureGalleryPermission(context);
    if (!ok) return null;

    final picked = await imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 100,
    );
    if (picked == null) return null;

    return await _convertToWebp(File(picked.path));
  }

  Future<List<XFile>?> showMultiImagePicker(
      BuildContext context,
      int? limit,
      ) async {
    final ok = await _ensureGalleryPermission(context);
    if (!ok) return null;

    final picks = await imagePicker.pickMultiImage(
      imageQuality: 100,
      limit: limit ?? 10,
    );

    if (picks.isEmpty) return null;

    final List<XFile> result = [];
    for (final img in picks) {
      final webp = await _convertToWebp(File(img.path));
      result.add(webp);
    }

    return result;
  }

  /// 카메라에서 이미지 촬영
  Future<XFile?> takePicture(BuildContext context) async {
    final ok = await _ensureCameraPermission(context);
    if (!ok) return null;

    final picked = await imagePicker.pickImage(
      source: ImageSource.camera,
      imageQuality: 100,
    );
    if (picked == null) return null;

    return await _convertToWebp(File(picked.path));
  }

  Future<XFile> _convertToWebp(File file) async {
    final targetPath = '${file.path}_webp.webp';

    final result = await FlutterImageCompress.compressAndGetFile(
      file.path,
      targetPath,
      quality: 80,
      keepExif: false,
      autoCorrectionAngle: true,
      format: CompressFormat.webp,
    );

    return XFile(result!.path);
  }

  Future<bool> _ensureGalleryPermission(BuildContext context) async {
    if (Platform.isIOS) {
      final status = await Permission.photos.request();

      if (status.isGranted || status.isLimited) {
        return true;
      }

      if (status.isPermanentlyDenied || status.isRestricted) {
        await _showOpenSettingsDialog(
          context,
          title: '사진 접근 권한이 필요해요',
          message: '앨범에서 이미지를 선택하려면 사진 접근 권한을 허용해주세요.',
        );
        return false;
      }

      _showPermissionDeniedSnackBar(context, '사진 접근 권한이 필요해요.');
      return false;
    }

    if (Platform.isAndroid) {
      // Android 13+ 는 photos, 구버전은 storage 케이스가 섞일 수 있어 둘 다 안전하게 처리
      PermissionStatus status = await Permission.photos.request();

      if (status.isGranted || status.isLimited) {
        return true;
      }

      if (status.isDenied) {
        final storageStatus = await Permission.storage.request();
        if (storageStatus.isGranted) {
          return true;
        }

        if (storageStatus.isPermanentlyDenied || storageStatus.isRestricted) {
          await _showOpenSettingsDialog(
            context,
            title: '사진 접근 권한이 필요해요',
            message: '앨범에서 이미지를 선택하려면 사진 접근 권한을 허용해주세요.',
          );
          return false;
        }

        _showPermissionDeniedSnackBar(context, '사진 접근 권한이 필요해요.');
        return false;
      }

      if (status.isPermanentlyDenied || status.isRestricted) {
        await _showOpenSettingsDialog(
          context,
          title: '사진 접근 권한이 필요해요',
          message: '앨범에서 이미지를 선택하려면 사진 접근 권한을 허용해주세요.',
        );
        return false;
      }

      _showPermissionDeniedSnackBar(context, '사진 접근 권한이 필요해요.');
      return false;
    }

    return true;
  }

  Future<bool> _ensureCameraPermission(BuildContext context) async {
    final status = await Permission.camera.request();

    if (status.isGranted) {
      return true;
    }

    if (status.isPermanentlyDenied || status.isRestricted) {
      await _showOpenSettingsDialog(
        context,
        title: '카메라 권한이 필요해요',
        message: '사진을 촬영하려면 카메라 권한을 허용해주세요.',
      );
      return false;
    }

    _showPermissionDeniedSnackBar(context, '카메라 권한이 필요해요.');
    return false;
  }

  Future<void> _showOpenSettingsDialog(
      BuildContext context, {
        required String title,
        required String message,
      }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('설정으로 이동'),
            ),
          ],
        );
      },
    );

    if (result == true) {
      await openAppSettings();
    }
  }

  void _showPermissionDeniedSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
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