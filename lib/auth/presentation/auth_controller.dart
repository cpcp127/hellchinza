import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:hellchinza/auth/presentation/auth_state.dart';
import 'package:hellchinza/services/shared_prefs_service.dart';
import 'package:hellchinza/utils/crypto_util.dart';
import 'package:kakao_flutter_sdk/kakao_flutter_sdk.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../data/user_mini_repo.dart';
import '../domain/user_mini.dart';

final authControllerProvider =
    StateNotifierProvider.autoDispose<AuthController, AuthState>((ref) {
      return AuthController(ref);
    });

class AuthController extends StateNotifier<AuthState> {
  final Ref ref;

  AuthController(this.ref) : super(AuthState());

  Future<void> signInWithApple() async {
    try {
      late final UserCredential userCredential;
      String? fullName;

      // ✅ Android: Firebase 공식 provider flow 사용
      if (Platform.isAndroid) {
        final appleProvider = AppleAuthProvider();
        appleProvider.addScope('email');
        appleProvider.addScope('name');

        userCredential = await FirebaseAuth.instance.signInWithProvider(
          appleProvider,
        );
      }
      // ✅ iOS: 기존 sign_in_with_apple 방식 유지
      else if (Platform.isIOS) {
        final rawNonce = CryptoUtil.generateNonce();
        final hashedNonce = CryptoUtil.sha256ofString(rawNonce);

        final appleCredential = await SignInWithApple.getAppleIDCredential(
          scopes: const [
            AppleIDAuthorizationScopes.email,
            AppleIDAuthorizationScopes.fullName,
          ],
          nonce: hashedNonce,
        );

        debugPrint('apple userIdentifier: ${appleCredential.userIdentifier}');
        debugPrint('apple authorizationCode: ${appleCredential.authorizationCode}');
        debugPrint('apple identityToken: ${appleCredential.identityToken}');
        debugPrint('apple givenName: ${appleCredential.givenName}');
        debugPrint('apple familyName: ${appleCredential.familyName}');

        final idToken = appleCredential.identityToken;
        if (idToken == null || idToken.isEmpty) {
          throw Exception('Apple identityToken is null or empty');
        }

        fullName = [
          appleCredential.familyName,
          appleCredential.givenName,
        ].whereType<String>().where((e) => e.trim().isNotEmpty).join('');

        final oauthCredential = AppleAuthProvider.credentialWithIDToken(
          idToken,
          rawNonce,
          AppleFullPersonName(
            givenName: appleCredential.givenName,
            familyName: appleCredential.familyName,
          ),
        );

        userCredential = await FirebaseAuth.instance.signInWithCredential(
          oauthCredential,
        );
      } else {
        throw UnsupportedError('Apple login is only supported on iOS/Android');
      }

      final user = userCredential.user;
      if (user == null) {
        throw Exception('Firebase user is null');
      }

      final firebaseRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid);

      final snap = await firebaseRef.get();

      if (!snap.exists) {
        await firebaseRef.set({
          'uid': user.uid,
          'email': user.email,
          'nickname': (fullName != null && fullName.isNotEmpty)
              ? fullName
              : user.displayName,
          'photoUrl': user.photoURL,
          'category': null,
          'description': null,
          'profileCompleted': false,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'provider': 'apple',
          'notificationSettings': {
            'like': true,
            'comment': true,
            'chat': true,
            'lightning': true,
          },
        });
      } else {
        await firebaseRef.update({
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    } on FirebaseAuthException catch (e, st) {
      debugPrint('Apple login FirebaseAuthException: ${e.code} / ${e.message}');
      debugPrint('$st');
      rethrow;
    } catch (e, st) {
      debugPrint('signInWithApple error: $e');
      debugPrint('$st');
      rethrow;
    }
  }
  Future<void> signInWithGoogle() async {
    final _auth = FirebaseAuth.instance;
    // 1) Google 인증(로그인)
    final googleUser = await GoogleSignIn.instance.authenticate();
    if (googleUser == null) return;

    // 2) 인증 토큰(idToken) 얻기 (v7에서는 accessToken이 없을 수 있음)
    final googleAuth = googleUser.authentication;
    final idToken = googleAuth.idToken;

    if (idToken == null) {
      throw Exception('idToken is null (check serverClientId / SHA1 setup)');
    }

    // 3) Firebase 로그인: idToken만으로 가능
    final credential = GoogleAuthProvider.credential(idToken: idToken);
    final userCredential = await _auth.signInWithCredential(credential);
    final user = userCredential.user;

    if (user == null) throw Exception('Firebase user is null');
    final firebaseRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid);
    final snap = await firebaseRef.get();

    if (!snap.exists) {
      // ✅ 완전 첫 가입: 기본 문서 생성 + profileCompleted=false
      await firebaseRef.set({
        'uid': user.uid,
        'email': user.email,
        'nickname': null,
        'photoUrl': null,
        'category': null,
        'description': null,
        'profileCompleted': false,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'notificationSettings': {
          'like': true,
          'comment': true,
          'chat': true,
          'lightning': true,
        },
      });
    }
  }

  Future<void> signInWithKakao() async {
    OAuthToken token = await UserApi.instance.loginWithKakaoAccount();
    var provider = OAuthProvider('oidc.unchin_kakao');
    var credential = provider.credential(
      idToken: token.idToken,
      accessToken: token.accessToken,
    );

    final _auth = FirebaseAuth.instance;

    final userCredential = await _auth.signInWithCredential(credential);
    final user = userCredential.user;

    if (user == null) throw Exception('Firebase user is null');
    final firebaseRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid);
    final snap = await firebaseRef.get();

    if (!snap.exists) {
      // ✅ 완전 첫 가입: 기본 문서 생성 + profileCompleted=false
      await firebaseRef.set({
        'uid': user.uid,
        'email': user.email,
        'nickname': null,
        'photoUrl': null,
        'category': null,
        'description': null,
        'profileCompleted': false,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'notificationSettings': {
          'like': true,
          'comment': true,
          'chat': true,
          'lightning': true,
        },
      });
    }
  }

  void onChangeNickname(String nickname) {
    state = state.copyWith(nickname: nickname);
  }

  void submitNickname(GlobalKey<FormState> formKey) {
    final isValid = formKey.currentState?.validate() ?? false;

    if (!isValid) {
      // ❌ 검증 실패 → 아무것도 안 함 (에러는 TextFormField가 표시)
      return;
    } else {
      print('통과');
    }

    // ✅ 검증 통과
    // 다음 단계 로직 실행
    // 예: Firestore 저장, 다음 페이지 이동 등
  }
}
