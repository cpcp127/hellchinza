import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:hellchinza/common/common_action_sheet.dart';
import 'package:image_picker/image_picker.dart';

import '../../auth/domain/user_mini.dart';
import '../../services/image_service.dart';
import '../../services/snackbar_service.dart';
import 'chat_room_state.dart';


extension _MapCopy on Map<String, String> {
  Map<String, String> copy() => Map<String, String>.from(this);
}

final otherUidProvider = Provider.family<String?, String>((ref, roomId) {
  final roomAsync = ref.watch(chatRoomProvider(roomId));
  final myUid = FirebaseAuth.instance.currentUser?.uid;

  return roomAsync.when(
    data: (doc) {
      final data = doc.data();
      if (data == null || myUid == null) return null;

      final type = (data['type'] ?? 'dm').toString();
      if (type != 'dm') return null;

      final members = List<String>.from(data['userUids'] ?? const []);
      final other = members.where((u) => u != myUid).toList();
      return other.isEmpty ? null : other.first;
    },
    loading: () => null,
    error: (_, __) => null,
  );
});
final chatControllerProvider =
StateNotifierProvider.family.autoDispose<ChatController, ChatState, String>(
      (ref, roomId) => ChatController(ref: ref, roomId: roomId)..init(),
);

final chatRoomProvider = StreamProvider.family<
    DocumentSnapshot<Map<String, dynamic>>, String>((ref, roomId) {
  return FirebaseFirestore.instance.collection('chatRooms').doc(roomId).snapshots();
});



class ChatController extends StateNotifier<ChatState> {
  ChatController({required this.ref, required this.roomId})
      : super(ChatState.initial(roomId: roomId)) {
    // ✅ provider가 dispose될 때 자동 호출
    ref.onDispose(() {
      // async라 await 못하니 fire-and-forget
      Future.microtask(() => leaveActive());
    });

    init();
  }

  final Ref ref;
  final String roomId;

  final ImageService _imageService = ImageService();

  FirebaseFirestore get _db => FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> get _roomRef =>
      _db.collection('chatRooms').doc(roomId);

  String get _myUid => FirebaseAuth.instance.currentUser!.uid;

  // ✅ heartbeat 타이머
  Timer? _heartbeatTimer;

  Future<void> init() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        state = state.copyWith(isLoading: false, errorMessage: '로그인이 필요합니다');
        return;
      }

      // 1) 내 uid 세팅
      state = state.copyWith(myUid: uid);

      // 2) roomData 1회 캐시(초기 canSend 계산용)
      final snap = await _roomRef.get();
      state = state.copyWith(isLoading: false, roomData: snap.data());
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }


  /// ✅ friend_request 수락
  Future<void> acceptFriendRequest({
    required String requestMessageId,
    required String otherUid,
  }) async {
    final myUid = _myUid;
    final roomRef = _roomRef;
    final msgRef = roomRef.collection('messages').doc(requestMessageId);

    // friends 저장: users/{uid}/friends/{otherUid}
    final myFriendRef =
    _db.collection('users').doc(myUid).collection('friends').doc(otherUid);
    final otherFriendRef =
    _db.collection('users').doc(otherUid).collection('friends').doc(myUid);

    await _db.runTransaction((tx) async {
      // ✅ READ 먼저
      final roomSnap = await tx.get(roomRef);
      final msgSnap = await tx.get(msgRef);

      if (!roomSnap.exists) throw Exception('채팅방이 없습니다');
      if (!msgSnap.exists) throw Exception('요청 메시지가 없습니다');

      final msg = msgSnap.data() as Map<String, dynamic>;
      final status = (msg['requestStatus'] ?? 'pending').toString();
      if (status != 'pending') return;

      // ✅ WRITE
      tx.update(roomRef, {
        'allowMessages': true,
        'friendshipStatus': 'accepted',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      tx.update(msgRef, {'requestStatus': 'accepted'});

      tx.set(myFriendRef, {
        'uid': otherUid,
        'createdAt': FieldValue.serverTimestamp(),
      });

      tx.set(otherFriendRef, {
        'uid': myUid,
        'createdAt': FieldValue.serverTimestamp(),
      });

      final sysRef = roomRef.collection('messages').doc();
      tx.set(sysRef, {
        'id': sysRef.id,
        'type': 'system',
        'authorUid': myUid,
        'text': '친구 요청을 수락했어요 🎉 이제 대화를 시작할 수 있어요.',
        'createdAt': FieldValue.serverTimestamp(),
      });

      tx.update(roomRef, {
        'lastMessageText': '친구 요청을 수락했어요 🎉',
        'lastMessageAt': FieldValue.serverTimestamp(),
        'lastMessageType':'accept_friend_request'
      });
    });

    // ✅ 즉시 반영(텍스트필드 활성화)
    ref.invalidate(chatRoomProvider(roomId));
  }

  /// ✅ friend_request 거절
  Future<void> rejectFriendRequest({
    required String requestMessageId,
  }) async {
    final myUid = _myUid;
    final roomRef = _roomRef;
    final msgRef = roomRef.collection('messages').doc(requestMessageId);

    await _db.runTransaction((tx) async {
      // ✅ READ 먼저
      final roomSnap = await tx.get(roomRef);
      final msgSnap = await tx.get(msgRef);

      if (!roomSnap.exists) throw Exception('채팅방이 없습니다');
      if (!msgSnap.exists) throw Exception('요청 메시지가 없습니다');

      final msg = msgSnap.data() as Map<String, dynamic>;
      final status = (msg['requestStatus'] ?? 'pending').toString();
      if (status != 'pending') return;

      // ✅ WRITE
      tx.update(roomRef, {
        'allowMessages': false,
        'friendshipStatus': 'rejected',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      tx.update(msgRef, {'requestStatus': 'rejected'});

      final sysRef = roomRef.collection('messages').doc();
      tx.set(sysRef, {
        'id': sysRef.id,
        'type': 'system',
        'authorUid': myUid,
        'text': '친구 요청을 거절했어요.',
        'createdAt': FieldValue.serverTimestamp(),
      });

      tx.update(roomRef, {
        'lastMessageText': '친구 요청을 거절했어요.',
        'lastMessageAt': FieldValue.serverTimestamp(),
        'lastMessageType':'reject_friend_request'
      });
    });

    ref.invalidate(chatRoomProvider(roomId));
  }

  Future<void> sendText({required String text}) async {
    final myUid = _myUid;
    final t = text.trim();
    if (t.isEmpty) return;

    final msgRef = _roomRef.collection('messages').doc();

    await _db.runTransaction((tx) async {
      final roomSnap = await tx.get(_roomRef);
      if (!roomSnap.exists) throw Exception('채팅방이 없습니다');

      final room = roomSnap.data()!;
      final type = (room['type'] ?? 'dm').toString();
      final allow = (room['allowMessages'] ?? false) == true;
      final canSend = (type == 'group') || allow;
      if (!canSend) throw Exception('친구가 되어야 메시지를 보낼 수 있어요');

      final userUids = List<String>.from(room['userUids'] ?? const []);
      final others = userUids.where((u) => u != myUid).toList();

      final unreadMap = Map<String, dynamic>.from(room['unreadCountMap'] ?? {});
      final activeAtMap = Map<String, dynamic>.from(room['activeAtMap'] ?? {});

      // ✅ 메시지 저장
      tx.set(msgRef, {
        'id': msgRef.id,
        'type': 'text',
        'authorUid': myUid, // ✅ senderUid 말고 authorUid로 통일
        'text': t,
        'createdAt': FieldValue.serverTimestamp(),
      });

      final now = DateTime.now();
      final updates = <String, dynamic>{
        'lastMessageText': t,
        'lastMessageAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // ✅ 상대 unreadCount 조건부 증가 (activeAt이 최근 30초면 증가 X)
      for (final otherUid in others) {
        final v = activeAtMap[otherUid];

        bool isActiveRecently = false;
        if (v is Timestamp) {
          final dt = v.toDate();
          isActiveRecently = now.difference(dt) <= const Duration(seconds: 30);
        }

        if (isActiveRecently) continue;

        final cur = (unreadMap[otherUid] ?? 0);
        final curInt = (cur is num) ? cur.toInt() : 0;
        updates['unreadCountMap.$otherUid'] = curInt + 1;
      }

      tx.update(_roomRef, updates);
    });
  }

  Future<UserMini?> fetchOtherUser(String roomId, String myUid) async {
    final roomSnap = await FirebaseFirestore.instance
        .collection('chatRooms')
        .doc(roomId)
        .get();

    final data = roomSnap.data();
    if (data == null) return null;

    final members = List<String>.from(data['userUids'] ?? const []);
    final otherUid = members.firstWhere((u) => u != myUid, orElse: () => '');
    if (otherUid.isEmpty) return null;

    final userSnap = await FirebaseFirestore.instance
        .collection('users')
        .doc(otherUid)
        .get();
    if (!userSnap.exists) return null;

    return UserMini.fromMap(userSnap.data()!,otherUid);
  }

  FirebaseStorage get _st => FirebaseStorage.instance;


  Future<void> leaveRoomAndUnfriend({String? otherUid}) async {
    final myUid = _myUid;

    await _db.runTransaction((tx) async {
      final roomSnap = await tx.get(_roomRef);
      if (!roomSnap.exists) throw Exception('채팅방이 없습니다');

      final room = roomSnap.data()!;
      final type = (room['type'] ?? 'dm').toString();
      final userUids = List<String>.from(room['userUids'] ?? const []);

      if (!userUids.contains(myUid)) return; // 이미 나간 상태

      // ✅ READ 먼저(요구조건)
      // (dm이면 friend 문서도 읽어도 되지만, 없어도 delete 가능)

      // 1) userUids에서 나 제거 → 내 채팅리스트에서 사라짐
      final newUserUids = [...userUids]..remove(myUid);

      // 2) 시스템 메시지
      final sysRef = _roomRef.collection('messages').doc();
      tx.set(sysRef, {
        'id': sysRef.id,
        'type': 'system',
        'authorUid': myUid,
        'text': '사용자가 채팅방을 나갔습니다.',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 3) 남은 사람은 입력 disable
      // - dm: 한 명이라도 나가면 allowMessages=false
      // - group: 정책에 따라 다르지만, 너 요구는 “남은 사람 disable”이라면 group도 false로.
      final updates = <String, dynamic>{
        'userUids': newUserUids,
        'allowMessages': false,
        'updatedAt': FieldValue.serverTimestamp(),
        'lastMessageText': '사용자가 채팅방을 나갔습니다.',
        'lastMessageAt': FieldValue.serverTimestamp(),
      };

      // 4) dm이면 친구끊기까지
      if (type == 'dm' && otherUid != null && otherUid.isNotEmpty) {
        final myFriendRef = _db.collection('users').doc(myUid).collection('friends').doc(otherUid);
        final otherFriendRef = _db.collection('users').doc(otherUid).collection('friends').doc(myUid);

        tx.delete(myFriendRef);
        tx.delete(otherFriendRef);

        // dm의 friendshipStatus도 정리(선택)
        updates['friendshipStatus'] = 'rejected';
      }

      tx.update(_roomRef, updates);
    });

    // 리스트/룸 상태 즉시 반영
    ref.invalidate(chatRoomProvider(roomId));
  }


  /// ✅ 방 들어올 때: unread 0 처리 + activeAt 갱신
  Future<void> enterRoom() async {
    final myUid = _myUid;

    await _roomRef.set({
      'unreadCountMap': {myUid: 0},
      'activeAtMap': {myUid: FieldValue.serverTimestamp()},
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// ✅ 화면이 살아있는 동안 주기적으로 activeAt 업데이트
  Future<void> heartbeat() async {
    final myUid = _myUid;
    await _roomRef.update({
      'activeAtMap.$myUid': FieldValue.serverTimestamp(),
    });
  }

  /// ✅ heartbeat 시작/중지
  void startHeartbeat() {
    _heartbeatTimer?.cancel();
    // 너무 잦으면 비용↑. 15초 추천 (활성판정 30초와 궁합 좋음)
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      heartbeat();
    });
  }

  void stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  /// ✅ 화면에서 나갈 때(뒤로가기/dispose 등): heartbeat 중지 + activeAt 제거(선택)
  Future<void> leaveActive() async {
    try {
      stopHeartbeat();

      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      await _roomRef.update({
        'activeAtMap.$uid': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(), // 선택
      });
    } catch (_) {
      // 나가는 순간엔 실패해도 앱이 죽으면 안됨
    }
  }

  /// ✅ 갤러리/카메라 선택 후 1장 전송
  Future<void> pickAndSendOneImage() async {
    final file = await _imageService.showImagePicker(); // webp 변환 포함
    if (file == null) return;
    await sendImage(file: file);
  }

  Future<void> takeAndSendOneImage() async {
    final file = await _imageService.takePicture(); // webp 변환 포함
    if (file == null) return;
    await sendImage(file: file);
  }

  /// ✅ 채팅용 액션시트(너 공통 바텀시트 그대로 재사용)
  Future<void> openChatImageSheet(BuildContext context) async {
    final items = <CommonActionSheetItem>[
      CommonActionSheetItem(
        icon: Icons.photo_camera,
        title: '카메라로 촬영하기',
        onTap: () async {
          await takeAndSendOneImage();
        },
      ),
      CommonActionSheetItem(
        icon: Icons.photo_library,
        title: '앨범에서 선택하기',
        onTap: () async {
          await pickAndSendOneImage();
        },
      ),

    ];

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => CommonActionSheet(
        title: '사진 전송',
        items: items,
      ),
    );

  }
  /// ✅ 카톡 스타일: 메시지 먼저 만들고, 업로드 완료되면 message 업데이트
  Future<void> sendImage({required XFile file}) async {
    final myUid = _myUid;

    // 0) 보낼 수 있는 상태인지 서버에서 확인(친구/그룹)
    final roomSnap = await _roomRef.get();
    if (!roomSnap.exists) throw Exception('채팅방이 없습니다');

    final room = roomSnap.data() ?? {};
    final type = (room['type'] ?? 'dm').toString();
    final allow = (room['allowMessages'] ?? false) == true;
    final canSend = (type == 'group') || allow;
    if (!canSend) throw Exception('친구가 되어야 메시지를 보낼 수 있어요');

    // 1) messageId 먼저 발급
    final msgRef = _roomRef.collection('messages').doc();
    final msgId = msgRef.id;

    // 2) ✅ UI에 즉시 로컬 이미지 보여주기 위해 state에 로컬 경로 저장
    final pending = state.pendingImageLocalPathByMsgId.copy();
    pending[msgId] = file.path;
    state = state.copyWith(pendingImageLocalPathByMsgId: pending);

    // 3) ✅ Firestore에 "업로드 중 메시지" 먼저 저장
    await msgRef.set({
      'id': msgId,
      'type': 'image',
      'authorUid': myUid,        // ✅ 너 규칙
      'imageUrl': null,          // 업로드 후 채움
      'uploadStatus': 'uploading',
      'createdAt': FieldValue.serverTimestamp(),
    });

    // 채팅방 마지막 메시지도 “사진(업로드중)”으로 먼저 갱신
    await _roomRef.update({
      'lastMessageText': '사진',
      'lastMessageAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // 4) ✅ Storage 업로드 (파일명은 msgId로 고정하면 관리 쉬움)
    try {
      final ext = file.path.toLowerCase().endsWith('.webp') ? 'webp' : 'jpg';

      final storageRef = FirebaseStorage.instance
          .ref()
          .child('chatRooms')
          .child(roomId)
          .child('images')
          .child('$msgId.$ext');

      final uploadTask = storageRef.putFile(File(file.path));
      final snap = await uploadTask;
      final url = await snap.ref.getDownloadURL();

      // 5) ✅ 업로드 완료 → 메시지 업데이트(overlay 사라짐)
      await msgRef.update({
        'imageUrl': url,
        'uploadStatus': 'done',
      });

      // 6) ✅ state pending 제거(이제 네트워크 이미지로 보여주면 됨)
      final pending2 = state.pendingImageLocalPathByMsgId.copy();
      pending2.remove(msgId);
      state = state.copyWith(pendingImageLocalPathByMsgId: pending2);

    } catch (e) {
      // 실패 표시
      await msgRef.update({
        'uploadStatus': 'failed',
      });

      // pending은 남겨두면 "재시도" 같은 UX도 만들 수 있음
      // 일단은 제거해도 됨(너 취향). 나는 남겨두는 걸 추천.
      // Snackbar도
      SnackbarService.show(
        type: AppSnackType.error,
        message: '이미지 업로드에 실패했습니다',
      );
    }
  }

}