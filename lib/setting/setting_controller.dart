import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:hellchinza/setting/setting_state.dart';

import '../constants/app_constants.dart';
import '../services/push_token_service.dart';

final settingControllerProvider =
StateNotifierProvider.autoDispose<SettingController, SettingState>(
      (ref) => SettingController(ref),
);

class SettingController extends StateNotifier<SettingState> {
  final Ref ref;

  SettingController(this.ref) : super(const SettingState());
  Future<void> init() async {
    state = state.copyWith(isLoading: true);

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        state = state.copyWith(isLoading: false);
        return;
      }

      final userRef = FirebaseFirestore.instance.collection('users').doc(uid);
      final snap = await userRef.get();
      final data = snap.data() ?? {};

      final rawSettings =
          (data['notificationSettings'] as Map<String, dynamic>?) ?? {};

      final updates = <String, dynamic>{};

      // ✅ 없는 키만 보정
      for (final entry in kDefaultNotificationSettings.entries) {
        if (!rawSettings.containsKey(entry.key)) {
          updates['notificationSettings.${entry.key}'] = entry.value;
        }
      }

      if (updates.isNotEmpty) {
        updates['updatedAt'] = FieldValue.serverTimestamp();
        await userRef.update(updates);
      }

      // ✅ state에는 항상 완성된 형태로 넣기
      final mergedSettings = <String, bool>{};
      for (final entry in kDefaultNotificationSettings.entries) {
        mergedSettings[entry.key] =
            (rawSettings[entry.key] as bool?) ?? entry.value;
      }

      state = state.copyWith(
        isLoading: false,
        notificationSettings: mergedSettings,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false);
      debugPrint('SettingController init error: $e');
    }
  }


  /// ✅ 로그아웃
  Future<void> logout(BuildContext context) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      await PushTokenService.instance.deleteCurrentToken();
      await FirebaseAuth.instance.signOut();
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).popUntil((route) => route.isFirst);
      }
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: '로그아웃에 실패했습니다.',
      );
      rethrow;
    }
  }

  /// Firebase Functions(Callable)로 서버 정리 + Auth 삭제까지 끝내는 흐름
  Future<void> deleteAccount() async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      // ✅ 1) callable 호출 (배포한 함수명)
      final functions = FirebaseFunctions.instanceFor(region: 'asia-northeast3');
      final callable = functions.httpsCallable('deleteUserData');

      // 필요하면 타임아웃/리트라이를 여기서 관리할 수도 있음
      final res = await callable.call();

      if (kDebugMode) {
        debugPrint('deleteUserData result: ${res.data}');
      }

      // ✅ 2) 함수가 admin.auth().deleteUser(uid)까지 했으면
      // 클라 세션은 남아있을 수 있어서 signOut 처리(안전)
      await FirebaseAuth.instance.signOut();

      state = state.copyWith(isLoading: false);
    } on FirebaseFunctionsException catch (e) {
      // Functions에서 throw한 HttpsError가 여기로 옴
      final msg = e.message ?? '회원탈퇴 실패';
      state = state.copyWith(isLoading: false, errorMessage: msg);
      rethrow;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: '회원탈퇴 실패');
      rethrow;
    }
  }

  Future<void> updateNotificationSetting(String key, bool value) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final ref = FirebaseFirestore.instance.collection('users').doc(uid);

    await ref.set({
      'notificationSettings.$key': value,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    state = state.copyWith(
      notificationSettings: {
        ...state.notificationSettings,
        key: value,
      },
    );
  }
}