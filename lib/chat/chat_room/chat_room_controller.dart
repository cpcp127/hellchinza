import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:image_picker/image_picker.dart';

import '../../../services/image_service.dart';
import '../../../services/snackbar_service.dart';
import '../providers/chat_provider.dart';
import 'chat_room_state.dart';

extension _MapCopy on Map<String, String> {
  Map<String, String> copy() => Map<String, String>.from(this);
}

class ChatController extends StateNotifier<ChatState> {
  ChatController({
    required this.ref,
    required this.roomId,
  }) : super(ChatState.initial(roomId: roomId)) {
    ref.onDispose(() {
      Future.microtask(() => leaveActive());
    });
  }

  final Ref ref;
  final String roomId;

  final ImageService _imageService = ImageService();
  Timer? _heartbeatTimer;

  Future<void> init() async {
    try {
      final repo = ref.read(chatRepoProvider);
      final uid = repo.currentUid;

      if (uid == null) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: '로그인이 필요합니다',
        );
        return;
      }

      final room = await repo.getRoomModel(roomId);

      state = state.copyWith(
        isLoading: false,
        myUid: uid,
        roomData: room == null
            ? null
            : {
          'type': room.type,
          'allowMessages': room.allowMessages,
          'userUids': room.userUids,
          'visibleUids': room.visibleUids,
          'unreadCountMap': room.unreadCountMap,
          'activeAtMap': room.activeAtMap,
        },
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  void setRoomData(Map<String, dynamic> roomData) {
    state = state.copyWith(roomData: roomData);
  }

  Future<void> acceptFriendRequest({
    required String requestMessageId,
    required String otherUid,
  }) async {
    await ref.read(chatRepoProvider).acceptFriendRequest(
      roomId: roomId,
      requestMessageId: requestMessageId,
      otherUid: otherUid,
    );
    ref.invalidate(chatRoomProvider(roomId));
  }

  Future<void> rejectFriendRequest({
    required String requestMessageId,
  }) async {
    await ref.read(chatRepoProvider).rejectFriendRequest(
      roomId: roomId,
      requestMessageId: requestMessageId,
    );
    ref.invalidate(chatRoomProvider(roomId));
  }

  Future<void> sendText({required String text}) async {
    await ref.read(chatRepoProvider).sendText(
      roomId: roomId,
      text: text,
    );
  }

  Future<void> enterRoom() async {
    await ref.read(chatRepoProvider).enterRoom(roomId);
  }

  Future<void> heartbeat() async {
    await ref.read(chatRepoProvider).heartbeat(roomId);
  }

  void startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      heartbeat();
    });
  }

  void stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  Future<void> leaveActive() async {
    try {
      stopHeartbeat();
      await ref.read(chatRepoProvider).leaveActive(roomId);
    } catch (_) {}
  }

  Future<void> pickAndSendOneImage(BuildContext context) async {
    final file = await _imageService.showImagePicker(context);
    if (file == null) return;

    final webpImage = await _imageService.convertToWebp(File(file.path));
    await sendImage(file: webpImage);
  }

  Future<void> takeAndSendOneImage(BuildContext context) async {
    final file = await _imageService.takePicture(context);
    if (file == null) return;

    final webpImage = await _imageService.convertToWebp(File(file.path));
    await sendImage(file: webpImage);
  }

  Future<void> sendImage({required XFile file}) async {
    final repo = ref.read(chatRepoProvider);

    final msgId = await repo.createUploadingImageMessage(
      roomId: roomId,
      file: file,
    );

    final pending = state.pendingImageLocalPathByMsgId.copy();
    pending[msgId] = file.path;
    state = state.copyWith(pendingImageLocalPathByMsgId: pending);

    try {
      final imageUrl = await repo.uploadChatImage(
        roomId: roomId,
        msgId: msgId,
        file: file,
      );

      await repo.markImageUploadDone(
        roomId: roomId,
        msgId: msgId,
        imageUrl: imageUrl,
      );

      final updated = state.pendingImageLocalPathByMsgId.copy();
      updated.remove(msgId);
      state = state.copyWith(pendingImageLocalPathByMsgId: updated);
    } catch (e) {
      await repo.markImageUploadFailed(roomId: roomId, msgId: msgId);
      SnackbarService.show(
        type: AppSnackType.error,
        message: '이미지 업로드에 실패했습니다',
      );
    }
  }

  Future<void> leaveRoomAndUnfriend({String? otherUid}) async {
    if (otherUid == null || otherUid.isEmpty) {
      throw Exception('상대 uid가 필요합니다');
    }

    await ref.read(chatRepoProvider).leaveRoomAndUnfriend(
      roomId: roomId,
      otherUid: otherUid,
    );
    ref.invalidate(chatRoomProvider(roomId));
  }

  Future<void> leaveGroupRoomAndMeet() async {
    await ref.read(chatRepoProvider).leaveGroupRoomAndMeet(roomId);
    ref.invalidate(chatRoomProvider(roomId));
  }

  DateTime? createdAtFrom(Map<String, dynamic> data) {
    return ref.read(chatRepoProvider).createdAtFrom(data);
  }

  bool isSameDay(DateTime a, DateTime b) {
    return ref.read(chatRepoProvider).isSameDay(a, b);
  }

  String formatDayKorean(DateTime d) {
    return ref.read(chatRepoProvider).formatDayKorean(d);
  }

  Future<void> toggleRoomPush({
    required String roomId,
    required String uid,
  }) async {
    await ref.read(chatRepoProvider).toggleRoomPush(
      roomId: roomId,
      uid: uid,
    );
  }
}