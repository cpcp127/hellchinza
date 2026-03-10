import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hellchinza/chat/chat_room/chat_room_view.dart';
import 'package:hellchinza/main.dart';

import '../feed/feed_detail/feed_detail_view.dart';

class PushTokenService {
  PushTokenService._();

  static final PushTokenService instance = PushTokenService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  Stream<String>? _tokenRefreshStream;
  bool _localInitialized = false;

  Future<void> init() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await _requestPermission();
    await _initLocalNotifications();
    await _setForegroundPresentationOptions();
    _listenForegroundMessages();

    _listenNotificationClick();   // 🔥 추가
    _checkInitialMessage();       // 🔥 추가

    final token = await _messaging.getToken();
    if (token != null && token.isNotEmpty) {
      await _saveToken(user.uid, token);
    }

    _tokenRefreshStream ??= _messaging.onTokenRefresh;
    _tokenRefreshStream!.listen((token) async {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;
      await _saveToken(currentUser.uid, token);
    });
  }

  void _listenNotificationClick() {
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('notification opened from background');
      _handleNavigation(message.data);
    });
  }

  Future<void> _checkInitialMessage() async {
    final message = await _messaging.getInitialMessage();

    if (message != null) {
      debugPrint('notification opened from terminated');
      _handleNavigation(message.data);
    }
  }
  void _handleNavigation(Map<String, dynamic> data) {
    final type = data['type'];

    if (type == 'comment' || type == 'like') {
      final feedId = data['feedId'];
      if (feedId == null) return;

      rootNavigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (_) => FeedDetailView(feedId: feedId),
        ),
      );
    }

    if (type == 'chat') {
      final roomId = data['roomId'];
      final roomType = data['roomType'];
      final otherUid = data['otherUid'];
      final meetId = data['meetId'];

      if (roomId == null || roomType == null) return;

      rootNavigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (_) => ChatView(
            roomId: roomId,
            roomType: roomType,
            otherUid: roomType == 'dm' ? otherUid : null,
            meetId: roomType == 'group' ? meetId : null,
          ),
        ),
      );
    }
  }

  Future<void> _requestPermission() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    debugPrint('FCM permission status: ${settings.authorizationStatus}');
  }

  Future<void> _initLocalNotifications() async {
    if (_localInitialized) return;

    const androidInit = AndroidInitializationSettings('@mipmap/launcher_icon');

    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );

    await _local.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: (response) {
        debugPrint('local notification tapped: ${response.payload}');
        if (response.payload == null) return;

        final data = Map<String, dynamic>.from(
          jsonDecode(response.payload!),
        );

        _handleNavigation(data);
      },
    );

    const socialChannel = AndroidNotificationChannel(
      'social',
      '소셜 알림',
      description: '좋아요, 댓글 알림',
      importance: Importance.high,
    );

    await _local
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(socialChannel);

    _localInitialized = true;
  }

  Future<void> _setForegroundPresentationOptions() async {
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  void _listenForegroundMessages() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      debugPrint('Foreground message: ${message.messageId}');
      debugPrint('Foreground data: ${message.data}');

      final notification = message.notification;
      final title = notification?.title ?? message.data['title'] ?? '알림';
      final body = notification?.body ?? message.data['body'] ?? '';
      final type = message.data['type'] ?? '';

      // Android는 foreground에서 local notification 직접 띄움
      if (!kIsWeb && Platform.isAndroid) {
        final channelId = _channelIdByType(type);

        await _local.show(
          title: title,
          body: body,
          notificationDetails: NotificationDetails(
            android: AndroidNotificationDetails(
              channelId,
              _channelNameByType(type),
              channelDescription: _channelDescriptionByType(type),
              importance: Importance.high,
              priority: Priority.high,
              icon: '@mipmap/launcher_icon',
            ),
          ),
          payload: jsonEncode(message.data),
          id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        );
      }

      // iOS는 setForegroundNotificationPresentationOptions로 시스템 표시
      // 중복 방지 위해 여기서 local.show()는 안 함
    });
  }

  String _channelIdByType(String type) {
    switch (type) {
      case 'chat':
        return 'chat';
      case 'lightning':
        return 'meet';
      case 'comment':
      case 'like':
      default:
        return 'social';
    }
  }

  String _channelNameByType(String type) {
    switch (type) {
      case 'chat':
        return '채팅 알림';
      case 'lightning':
        return '모임 알림';
      case 'comment':
      case 'like':
      default:
        return '소셜 알림';
    }
  }

  String _channelDescriptionByType(String type) {
    switch (type) {
      case 'chat':
        return '채팅 메시지 알림';
      case 'lightning':
        return '모임 및 번개 알림';
      case 'comment':
      case 'like':
      default:
        return '좋아요, 댓글 알림';
    }
  }

  Future<void> _saveToken(String uid, String token) async {
    final docRef = FirebaseFirestore.instance
        .collection('users')
        .doc(uid);

    await docRef.set({
      'fcmTokens': FieldValue.arrayUnion([token]),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  String _platformName() {
    if (kIsWeb) return 'web';
    if (Platform.isIOS) return 'ios';
    if (Platform.isAndroid) return 'android';
    return 'unknown';
  }

  Future<void> deleteCurrentToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final token = await _messaging.getToken();
    if (token == null || token.isEmpty) return;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .update({
      'fcmTokens': FieldValue.arrayRemove([token]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
