import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:hellchinza/meet/meet_list/meet_list_controller.dart';
import 'package:image_picker/image_picker.dart';

import '../domain/meet_model.dart';
import '../domain/meet_region.dart';
import 'meet_create_state.dart';
import '../../services/image_service.dart';
import '../../services/snackbar_service.dart';

final meetCreateControllerProvider =
    StateNotifierProvider.autoDispose<MeetCreateController, MeetCreateState>((
      ref,
    ) {
      return MeetCreateController(ref);
    });

class MeetCreateController extends StateNotifier<MeetCreateState> {
  MeetCreateController(this.ref) : super(MeetCreateState.initial());

  final Ref ref;

  Future<void> initForEdit(String meetId) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final snap = await FirebaseFirestore.instance
          .collection('meets')
          .doc(meetId)
          .get();
      if (!snap.exists) {
        state = state.copyWith(isLoading: false, errorMessage: '모임을 찾을 수 없어요');
        return;
      }

      final meet = MeetModel.fromDoc(snap);

      state = state.copyWith(
        isLoading: false,
        step: 0,
        editingMeetId: meet.id,
        title: meet.title,
        intro: meet.intro,
        category: meet.category,
        regions: meet.regions,
        maxMembersText: meet.maxMembers.toString(),
        needApproval: meet.needApproval,
        existingThumbnailUrl: meet.imageUrls.isNotEmpty
            ? meet.imageUrls.first
            : null,
        removeExistingThumbnail: false,
        clearThumbnail: true,
        errorMessage: null,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: '불러오기에 실패했어요');
    }
  }

  // ---- setters ----
  void setTitle(String v) =>
      state = state.copyWith(title: v, errorMessage: null);

  void setIntro(String v) =>
      state = state.copyWith(intro: v, errorMessage: null);

  void selectCategory(String v) =>
      state = state.copyWith(category: v, errorMessage: null);

  void addRegion(MeetRegion r) {
    if (state.regions.any((e) => e.code == r.code)) return;
    state = state.copyWith(regions: [...state.regions, r], errorMessage: null);
  }

  void removeRegion(String code) {
    state = state.copyWith(
      regions: state.regions.where((e) => e.code != code).toList(),
    );
  }

  void setMaxMembersText(String v) {
    final onlyDigits = v.replaceAll(RegExp(r'[^0-9]'), '');
    state = state.copyWith(maxMembersText: onlyDigits, errorMessage: null);
  }

  void toggleNeedApproval(bool v) => state = state.copyWith(needApproval: v);

  // ---- thumbnail ----
  Future<void> pickThumbnail(BuildContext context) async {
    final file = await ImageService().showImagePicker(context);
    if (file == null) return;
    final webpImage = await ImageService().convertToWebp(File(file.path));

    // 새로 고르면 기존 삭제 플래그 해제(교체 우선)
    state = state.copyWith(
      thumbnail: webpImage,
      removeExistingThumbnail: false,
      errorMessage: null,
    );
  }

  void removeThumbnail() {
    if (state.thumbnail != null) {
      state = state.copyWith(clearThumbnail: true);
      return;
    }
    // 기존 썸네일 삭제
    if (state.existingThumbnailUrl != null) {
      state = state.copyWith(removeExistingThumbnail: true, errorMessage: null);
    }
  }

  // ---- step ----
  void back() {
    if (state.step <= 0) return;
    state = state.copyWith(step: state.step - 1, errorMessage: null);
  }

  void next() {
    if (!state.canGoNext) {
      state = state.copyWith(errorMessage: _stepErrorMessage(state.step));
      return;
    }
    if (state.isLast) return;
    state = state.copyWith(step: state.step + 1, errorMessage: null);
  }

  String _stepErrorMessage(int step) {
    switch (step) {
      case 0:
        return '모임 이름과 설명을 입력해주세요';
      case 1:
        return '운동 종류를 선택해주세요';
      case 2:
        return '주요 활동 지역을 1개 이상 추가해주세요';
      case 3:
        return '최대 인원을 2~1000 사이 숫자로 입력해주세요';
      case 5:
        return '썸네일을 등록해주세요';
      default:
        return '필수 정보를 확인해주세요';
    }
  }

  Future<void> submit() async {
    if (!state.isLast || !state.canGoNext) {
      state = state.copyWith(errorMessage: _stepErrorMessage(state.step));
      return;
    }

    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final db = FirebaseFirestore.instance;
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw Exception('로그인이 필요해요');

      final isEdit = state.editingMeetId != null;
      final meetId = isEdit ? state.editingMeetId! : db.collection('meets').doc().id;

      final meetRef = db.collection('meets').doc(meetId);
      final maxMembers = int.parse(state.maxMembersText.trim());

      final update = <String, dynamic>{
        'id': meetId,
        'authorUid': uid,
        'title': state.title.trim(),
        'intro': state.intro.trim(),
        'category': state.category,
        'regions': state.regions.map((e) => e.toJson()).toList(),
        'maxMembers': maxMembers,
        'needApproval': state.needApproval,
        'updatedAt': FieldValue.serverTimestamp(),
        'searchKeywords': _buildSearchKeywords(),
      };

      // ✅ 썸네일 처리(교체/삭제/유지)
      if (state.thumbnail != null) {
        final url = await _uploadMeetThumb(meetId, state.thumbnail!);
        update['imageUrls'] = [url];
      } else if (state.removeExistingThumbnail) {
        await _deleteMeetThumb(meetId);
        update['imageUrls'] = [];
      }
      // else: 수정 시 기존 유지

      if (!isEdit) {
        final now = FieldValue.serverTimestamp();

        final create = <String, dynamic>{
          ...update,
          'status': 'open',
          'currentMemberCount': 1,
          'createdAt': now,
          'chatRoomId': meetId,
        };

        final memberRef = meetRef.collection('members').doc(uid);

        final chatRoomRef = db.collection('chatRooms').doc(meetId);
        final firstMsgRef = chatRoomRef.collection('messages').doc();

        final batch = db.batch();

        // 1) meet 생성
        batch.set(meetRef, create);

        // 2) host member 생성
        batch.set(memberRef, <String, dynamic>{
          'uid': uid,
          'role': 'host', // host / member
          'status': 'approved',
          'joinedAt': now,
          'createdAt': now,
          'updatedAt': now,
        });

        // 3) group chatRoom 생성
        batch.set(chatRoomRef, <String, dynamic>{
          'type': 'group',
          'meetId': meetId,
          'title': state.title.trim(),
          'allowMessages': true,

          // ✅ 채팅방은 array 유지
          'userUids': [uid],
          'visibleUids': [uid],

          'unreadCountMap': {uid: 0},
          'activeAtMap': {uid: now},

          'lastMessageAt': now,
          'lastMessageText': '모임 채팅이 생성되었어요 🎉',
          'lastMessageType': 'system',

          'createdAt': now,
          'updatedAt': now,
        });

        // 4) 첫 시스템 메시지
        batch.set(firstMsgRef, <String, dynamic>{
          'id': firstMsgRef.id,
          'type': 'system',
          'text': '모임 채팅이 생성되었어요 🎉',
          'authorUid': uid,
          'createdAt': now,
        });

        await batch.commit();
      } else {
        await meetRef.update(update);

        // 제목 수정 시 채팅방 title도 같이 맞추고 싶으면 같이 업데이트
        await db.collection('chatRooms').doc(meetId).update({
          'title': state.title.trim(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      ref.read(meetListControllerProvider.notifier).refresh();

      state = state.copyWith(isLoading: false);

      SnackbarService.show(
        type: AppSnackType.success,
        message: isEdit ? '모임이 수정되었습니다' : '모임이 생성되었습니다',
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: '저장에 실패했어요',
      );

      SnackbarService.show(
        type: AppSnackType.error,
        message: '저장에 실패했어요',
      );
      rethrow;
    }
  }

  Future<String> _uploadMeetThumb(String meetId, XFile file) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    final ref = FirebaseStorage.instance
        .ref()
        .child('meets')
        .child(meetId)
        .child('thumb.webp'); // 항상 같은 이름으로 덮어쓰기

    final meta = SettableMetadata(
      contentType: 'image/webp',
      customMetadata: {'uploaderUid': uid, 'meetId': meetId},
    );

    await ref.putFile(File(file.path), meta);
    return await ref.getDownloadURL();
  }

  Future<void> _deleteMeetThumb(String meetId) async {
    final ref = FirebaseStorage.instance
        .ref()
        .child('meets')
        .child(meetId)
        .child('thumb.webp');

    try {
      await ref.delete();
    } catch (_) {}
  }

  List<String> _buildSearchKeywords() {
    final title = state.title.trim();
    final intro = state.intro.trim();
    final category = state.category;
    final regions = state.regions.map((e) => e.fullName).toList();

    final text = '$title $intro $category ${regions.join(" ")}'.toLowerCase();

    final words = text.split(RegExp(r'\s+'));

    final result = <String>{};

    for (final word in words) {
      if (word.isEmpty) continue;

      // 단어 자체
      result.add(word);

      // prefix 검색 (헬, 헬스)
      for (int i = 1; i <= word.length; i++) {
        result.add(word.substring(0, i));
      }
    }

    return result.toList();
  }
}
