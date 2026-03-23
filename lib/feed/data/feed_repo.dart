import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/storage_upload_service.dart';
import '../domain/feed_model.dart';
import '../domain/feed_place.dart';

class FeedPageResult {
  final List<FeedModel> items;
  final DocumentSnapshot<Map<String, dynamic>>? lastDoc;
  final bool hasMore;

  const FeedPageResult({
    required this.items,
    required this.lastDoc,
    required this.hasMore,
  });
}

class FeedRepo {
  FeedRepo(this._db, this._auth, this._storage);

  final FirebaseFirestore _db;
  final fb_auth.FirebaseAuth _auth;
  final FirebaseStorage _storage;

  String get currentUidOrThrow {
    final uid = _auth.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      throw Exception('로그인이 필요합니다');
    }
    return uid;
  }

  Future<FeedModel?> getFeed(String feedId) async {
    final doc = await _db.collection('feeds').doc(feedId).get();
    if (!doc.exists || doc.data() == null) return null;
    return FeedModel.fromJson(doc.data()!);
  }

  Stream<List<String>> watchMyFriendUids() {
    final myUid = _auth.currentUser?.uid;
    if (myUid == null) return Stream.value(const []);

    return _db
        .collection('users')
        .doc(myUid)
        .collection('friends')
        .snapshots()
        .map((snap) {
          return snap.docs
              .map((d) => (d.data()['uid'] ?? d.id).toString())
              .where((e) => e.isNotEmpty)
              .toList();
        });
  }

  Stream<List<String>> watchMyBlockedUids() {
    final myUid = _auth.currentUser?.uid;
    if (myUid == null) return Stream.value(const []);

    return _db
        .collection('users')
        .doc(myUid)
        .collection('blocks')
        .snapshots()
        .map((snap) {
          return snap.docs
              .map((d) => (d.data()['uid'] ?? d.id).toString())
              .where((e) => e.isNotEmpty)
              .toList();
        });
  }

  Query<Map<String, dynamic>> buildFeedBaseQuery({
    required String mainType,
    required String subType,
  }) {
    Query<Map<String, dynamic>> query = _db.collection('feeds');

    if (mainType != '전체') {
      query = query.where('mainType', isEqualTo: mainType);
    }

    if (mainType != '식단' && subType != '전체') {
      query = query.where('subType', isEqualTo: subType);
    }

    query = query.where('meetId', isNull: true);
    query = query.orderBy('createdAt', descending: true);

    return query;
  }

  bool _isPublicVisibility(Map<String, dynamic> data) {
    final visibility = data['visibility']?.toString();
    return visibility == null ||
        visibility.isEmpty ||
        visibility == FeedVisibility.public;
  }

  bool _isFriendsVisibility(Map<String, dynamic> data) {
    final visibility = data['visibility']?.toString();
    return visibility == FeedVisibility.friends;
  }

  bool canViewFeed({
    required Map<String, dynamic> data,
    required String myUid,
    required Set<String> blockedUidSet,
    required Set<String> friendUidSet,
    required bool onlyFriendFeeds,
  }) {
    final authorUid = (data['authorUid'] ?? '').toString();
    if (authorUid.isEmpty) return false;
    if (blockedUidSet.contains(authorUid)) return false;

    final isMine = authorUid == myUid;
    final isFriendAuthor = friendUidSet.contains(authorUid);
    final isPublic = _isPublicVisibility(data);
    final isFriendsOnly = _isFriendsVisibility(data);

    if (onlyFriendFeeds) {
      if (!isMine && !isFriendAuthor) return false;
      if (isPublic) return true;
      if (isFriendsOnly) return true;
      return false;
    }

    if (isMine) return true;
    if (isPublic) return true;
    if (isFriendsOnly && isFriendAuthor) return true;
    return false;
  }

  Future<FeedPageResult> fetchFeedPage({
    required String mainType,
    required String subType,
    required bool onlyFriendFeeds,
    required List<String> blockedUids,
    required List<String> friendUids,
    required int pageSize,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
  }) async {
    final myUid = _auth.currentUser?.uid ?? '';
    final blockedSet = blockedUids.toSet();
    final friendSet = friendUids.toSet();

    final visibleItems = <FeedModel>[];
    DocumentSnapshot<Map<String, dynamic>>? cursor = startAfter;
    bool hasMore = true;

    while (visibleItems.length < pageSize && hasMore) {
      Query<Map<String, dynamic>> query = buildFeedBaseQuery(
        mainType: mainType,
        subType: subType,
      ).limit(pageSize * 2);

      if (cursor != null) {
        query = query.startAfterDocument(cursor);
      }

      final snap = await query.get();
      final docs = snap.docs;

      if (docs.isEmpty) {
        hasMore = false;
        break;
      }

      cursor = docs.last;

      for (final d in docs) {
        final data = d.data();

        final canView = canViewFeed(
          data: data,
          myUid: myUid,
          blockedUidSet: blockedSet,
          friendUidSet: friendSet,
          onlyFriendFeeds: onlyFriendFeeds,
        );

        if (!canView) continue;

        try {
          visibleItems.add(FeedModel.fromJson(data));
        } catch (_) {}
        if (visibleItems.length >= pageSize) break;
      }

      if (docs.length < pageSize * 2) {
        hasMore = false;
      }
    }

    return FeedPageResult(
      items: visibleItems,
      lastDoc: cursor,
      hasMore: hasMore,
    );
  }

  Map<String, dynamic>? buildPollMapOrNull(List<String> pollOptions) {
    final cleaned = pollOptions
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (cleaned.length < 2) return null;

    return {
      'options': cleaned.asMap().entries.map((e) {
        return {
          'id': 'option_${e.key + 1}',
          'text': e.value,
          'voterUids': <String>[],
        };
      }).toList(),
    };
  }

  Future<void> createFeed({
    required String mainType,
    required String? subType,
    required String contents,
    required List<XFile> newImageFiles,
    required List<String> pollOptions,
    required FeedPlace? selectedPlace,
    required String visibility,
    required String? meetId,
    required void Function(double value) onProgress,
  }) async {
    final uid = currentUidOrThrow;
    final feedRef = _db.collection('feeds').doc();
    final feedId = feedRef.id;

    onProgress(0);

    await feedRef.set({
      'id': feedId,
      'authorUid': uid,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'mainType': mainType,
      'subType': subType,
      'contents': contents.trim().isEmpty ? null : contents.trim(),
      'imageUrls': null,
      'poll': buildPollMapOrNull(pollOptions),
      'place': selectedPlace?.toJson(),
      'commentCount': 0,
      'meetId': meetId,
      'visibility': meetId == null ? visibility : FeedVisibility.public,
    });

    List<String>? imageUrls;

    if (newImageFiles.isNotEmpty) {
      final results = await const StorageUploadService()
          .uploadFeedImagesWithProgress(
            feedId: feedId,
            uid: uid,
            files: newImageFiles,
            onProgress: onProgress,
          );
      imageUrls = results.map((e) => e.url).toList();
    } else {
      onProgress(1);
    }

    await feedRef.update({
      'imageUrls': imageUrls,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateFeed({
    required String feedId,
    required String mainType,
    required String? subType,
    required String contents,
    required List<String> existingImageUrls,
    required List<XFile> newImageFiles,
    required List<String> removedImageUrls,
    required List<String> pollOptions,
    required FeedPlace? selectedPlace,
    required String visibility,
    required void Function(double value) onProgress,
  }) async {
    final uid = currentUidOrThrow;
    final feedRef = _db.collection('feeds').doc(feedId);

    onProgress(0);

    for (final url in removedImageUrls) {
      try {
        await _storage.refFromURL(url).delete();
      } catch (_) {}
    }

    List<String> uploadedUrls = [];

    if (newImageFiles.isNotEmpty) {
      final results = await const StorageUploadService()
          .uploadFeedImagesWithProgress(
            feedId: feedId,
            uid: uid,
            files: newImageFiles,
            onProgress: onProgress,
          );
      uploadedUrls = results.map((e) => e.url).toList();
    } else {
      onProgress(1);
    }

    final finalImageUrls = [...existingImageUrls, ...uploadedUrls];

    await feedRef.update({
      'mainType': mainType,
      'subType': subType,
      'contents': contents.trim().isEmpty ? null : contents.trim(),
      'poll': buildPollMapOrNull(pollOptions),
      'imageUrls': finalImageUrls.isEmpty ? null : finalImageUrls,
      'updatedAt': FieldValue.serverTimestamp(),
      'place': selectedPlace?.toJson(),
      'visibility': visibility,
    });
  }
}
