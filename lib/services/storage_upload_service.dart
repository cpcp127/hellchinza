import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class UploadResult {
  final String url; // downloadURL
  final String path; // storage fullPath (예: users/uid/profile/xxx.webp)
  const UploadResult({required this.url, required this.path});
}

class StorageUploadService {
  const StorageUploadService();

  Future<UploadResult> uploadProfileImage({
    required String uid,
    required XFile file,
  }) async {
    final storage = FirebaseStorage.instance;

    final ext = file.path.split('.').last.toLowerCase();
    final filename = 'profile_${DateTime.now().millisecondsSinceEpoch}.$ext';

    // ✅ 우리가 정한 경로
    final ref = storage.ref().child('users/$uid/profile/$filename');

    final metadata = SettableMetadata(
      contentType: ext == 'webp' ? 'image/webp' : 'image/$ext',
      cacheControl: 'public,max-age=604800',
    );

    await ref.putFile(File(file.path), metadata);

    final url = await ref.getDownloadURL();
    final path = ref.fullPath; // ✅ 이게 photoPath로 저장할 값

    return UploadResult(url: url, path: path);
  }


  /// ===============================
  /// ✅ 피드 이미지 여러 장 업로드 (추가)
  /// ===============================
  Future<List<UploadResult>> uploadFeedImages({
    required String feedId,
    required String uid,
    required List<XFile> files,
  }) async {
    final storage = FirebaseStorage.instance;
    final List<UploadResult> results = [];

    for (int i = 0; i < files.length; i++) {
      final file = files[i];
      final ext = file.path.split('.').last.toLowerCase();

      final filename =
          'feed_${DateTime.now().millisecondsSinceEpoch}_$i.$ext';

      // ✅ 우리가 정한 피드 이미지 경로
      final ref = storage.ref().child(
        'feeds/$feedId/images/$filename',
      );

      final metadata = SettableMetadata(
        contentType: ext == 'webp' ? 'image/webp' : 'image/$ext',
        cacheControl: 'public,max-age=604800',
      );

      await ref.putFile(File(file.path), metadata);

      final url = await ref.getDownloadURL();
      final path = ref.fullPath;

      results.add(
        UploadResult(
          url: url,
          path: path,
        ),
      );
    }

    return results;
  }
}
extension FeedUploadWithProgress on StorageUploadService {
  Future<List<UploadResult>> uploadFeedImagesWithProgress({
    required String feedId,
    required String uid,
    required List<XFile> files,
    required ValueChanged<double> onProgress,
  }) async {
    final storage = FirebaseStorage.instance;
    final List<UploadResult> results = [];

    // 파일 단위로 0~1 진행률 (간단 버전: 장수 기준)
    int done = 0;

    for (int i = 0; i < files.length; i++) {
      final file = files[i];
      final ext = file.path.split('.').last.toLowerCase();
      final filename = 'feed_${DateTime.now().millisecondsSinceEpoch}_$i.$ext';

      final ref = storage.ref().child('feeds/$feedId/images/$filename');

      final metadata = SettableMetadata(
        contentType: ext == 'webp' ? 'image/webp' : 'image/$ext',
        cacheControl: 'public,max-age=604800',
      );

      await ref.putFile(File(file.path), metadata);

      final url = await ref.getDownloadURL();
      results.add(UploadResult(url: url, path: ref.fullPath));

      done++;
      onProgress(done / files.length); // ✅ 1/3, 2/3, 3/3
    }

    return results;
  }
}
