import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../common/common_action_sheet.dart';

class FeedService {
  const FeedService();

  Future<void> toggleLike({
    required String feedId,
    required String myUid,
  }) async {
    final ref = FirebaseFirestore.instance.collection('feeds').doc(feedId);

    await FirebaseFirestore.instance.runTransaction((tx) async {
      final snapshot = await tx.get(ref);

      if (!snapshot.exists) return;

      final data = snapshot.data()!;
      final List likeUids = data['likeUids'] ?? [];

      if (likeUids.contains(myUid)) {
        // 💔 좋아요 취소
        tx.update(ref, {
          'likeUids': FieldValue.arrayRemove([myUid]),
        });
      } else {
        // ❤️ 좋아요
        tx.update(ref, {
          'likeUids': FieldValue.arrayUnion([myUid]),
        });
      }
    });
  }

  Future<void> showFeedMoreActionSheet({
    required BuildContext context,
    required bool isMine,
    VoidCallback? onEdit,
    VoidCallback? onDelete,
    VoidCallback? onReport,
  }) async {
    final items = <CommonActionSheetItem>[
      if (isMine) ...[
        CommonActionSheetItem(
          icon: Icons.edit_outlined,
          title: '수정하기',
          onTap: onEdit ?? () {},
        ),
        CommonActionSheetItem(
          icon: Icons.delete_outline,
          title: '삭제하기',
          onTap: onDelete ?? () {},
          isDestructive: true,
        ),
      ] else ...[
        CommonActionSheetItem(
          icon: Icons.flag_outlined,
          title: '신고하기',
          onTap: onReport ?? () {},
          isDestructive: true,
        ),
      ],
    ];

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) =>
          CommonActionSheet(title: isMine ? '내 피드' : '피드', items: items),
    );
  }

  Future<void> deleteFeed({required String feedId}) async {
    final firestore = FirebaseFirestore.instance
        .collection('feeds')
        .doc(feedId);
    final storage = FirebaseStorage.instance;

    // 1️⃣ Storage: feeds/{feedId}/ 아래 모든 파일 삭제
    final feedFolderRef = storage.ref('feeds/$feedId/images');

    try {
      final ListResult result = await feedFolderRef.listAll();

      for (final Reference ref in result.items) {
        try {
          await ref.delete();
        } catch (e) {
          debugPrint('Failed to delete file: ${ref.fullPath}');
        }
      }
    } catch (e) {
      // 폴더 자체가 없는 경우도 정상
      debugPrint('No storage files for feed: $feedId');
    }

    // 2️⃣ Firestore 문서 삭제
    await firestore.delete();
  }

  Future<void> openNaverMapPlace({
    required String title,
    required double lat,
    required double lng,
  }) async {
    final packageName = (await PackageInfo.fromPlatform()).packageName;

   // final encodedTitle = Uri.encodeComponent(title);
    var result = title.replaceAll('&', ' ');

    // 2. 특수문자 중 검색 품질 해치는 것 제거
    // (괄호, 슬래시, 콜론 등)
    result = result.replaceAll(
      RegExp(r'[^\w\s가-힣]'),
      ' ',
    );

    // 3. 공백 정리
    result = result.replaceAll(RegExp(r'\s+'), ' ');
    // 네이버 지도 앱
    final appUri = Uri.parse(
      'nmap://map'
          '?lat=$lat&lng=$lng&zoom=16'
          '&marker=lat:$lat,lng:$lng,name:$result'
          '&appname=$packageName',
    );

    // 네이버 지도 웹 (fallback)
    final webUri = Uri.parse(
      'https://map.naver.com/v5/search/$result'
          '?c=$lng,$lat,16,0,0,0,dh',
    );

    if (await canLaunchUrl(appUri)) {
      await launchUrl(appUri, mode: LaunchMode.externalApplication);
      return;
    }

    await launchUrl(webUri, mode: LaunchMode.externalApplication);
  }
  /// 댓글 등록
  Future<void> addComment({
    required String feedId,
    required String content,
  }) async {
    final user = FirebaseAuth.instance.currentUser!;
    final firestore = FirebaseFirestore.instance;

    // 사용자 정보 (이미 provider로 들고 있다면 그걸 써도 됨)
    final userSnap =
    await firestore.collection('users').doc(user.uid).get();
    final userData = userSnap.data() ?? {};

    final commentRef = firestore
        .collection('feeds')
        .doc(feedId)
        .collection('comments')
        .doc();

    await commentRef.set({
      'id': commentRef.id,
      'feedId': feedId,

      'authorUid': user.uid,
      'authorNickname': userData['nickname'] ?? '',
      'authorPhotoUrl': userData['photoUrl'],

      'content': content,
      'createdAt': FieldValue.serverTimestamp(),
      'refreshToken': DateTime.now().millisecondsSinceEpoch, // 🔥
    });
  }

  /// 댓글 삭제
  Future<void> deleteComment({
    required String feedId,
    required String commentId,
    required int valueKey,
  }) async {
    final firestore = FirebaseFirestore.instance;

    await firestore
        .collection('feeds')
        .doc(feedId)
        .collection('comments')
        .doc(commentId)
        .delete();
    valueKey++;
    await FirebaseFirestore.instance.runTransaction((tx) async {
      final feedRef =
      FirebaseFirestore.instance.collection('feeds').doc(feedId);

      tx.update(feedRef, {
        'commentCount': FieldValue.increment(-1),
      });
    });
  }

  Future<void> vote({
    required String feedId,
    required String newOptionId,
  }) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final ref = FirebaseFirestore.instance.collection('feeds').doc(feedId);

    await FirebaseFirestore.instance.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final data = snap.data()!;
      final poll = data['poll'] as Map<String, dynamic>;
      final options = List<Map<String, dynamic>>.from(poll['options']);

      for (final o in options) {
        final voters = List<String>.from(o['voterUids'] ?? []);
        voters.remove(uid); // 기존 투표 제거
        if (o['id'] == newOptionId) {
          voters.add(uid); // 새 투표
        }
        o['voterUids'] = voters;
      }

      tx.update(ref, {
        'poll.options': options,
      });
    });
  }

}
