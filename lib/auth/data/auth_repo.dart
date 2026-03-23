import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:kakao_flutter_sdk/kakao_flutter_sdk.dart' hide User;
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import 'package:hellchinza/utils/crypto_util.dart';

class AuthRepo {
  AuthRepo(this._auth, this._db);

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;

  Future<void> signInWithApple() async {
    late final UserCredential userCredential;
    String? fullName;

    if (Platform.isAndroid) {
      final appleProvider = AppleAuthProvider()
        ..addScope('email')
        ..addScope('name');

      userCredential = await _auth.signInWithProvider(appleProvider);
    } else if (Platform.isIOS) {
      final rawNonce = CryptoUtil.generateNonce();
      final hashedNonce = CryptoUtil.sha256ofString(rawNonce);

      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: const [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: hashedNonce,
      );

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

      userCredential = await _auth.signInWithCredential(oauthCredential);
    } else {
      throw UnsupportedError('Apple login is only supported on iOS/Android');
    }

    final user = userCredential.user;
    if (user == null) {
      throw Exception('Firebase user is null');
    }

    await _createOrTouchUser(
      user: user,
      provider: 'apple',
      nickname: (fullName != null && fullName.isNotEmpty)
          ? fullName
          : user.displayName,
      photoUrl: user.photoURL,
    );
  }

  Future<void> signInWithGoogle() async {
    final googleUser = await GoogleSignIn.instance.authenticate();
    if (googleUser == null) return;

    final googleAuth = googleUser.authentication;
    final idToken = googleAuth.idToken;

    if (idToken == null) {
      throw Exception('idToken is null (check serverClientId / SHA1 setup)');
    }

    final credential = GoogleAuthProvider.credential(idToken: idToken);
    final userCredential = await _auth.signInWithCredential(credential);
    final user = userCredential.user;

    if (user == null) {
      throw Exception('Firebase user is null');
    }

    await _createOrTouchUser(
      user: user,
      provider: 'google',
      nickname: null,
      photoUrl: null,
    );
  }

  Future<void> signInWithKakao() async {
    final token = await UserApi.instance.loginWithKakaoAccount();
    final provider = OAuthProvider('oidc.unchin_kakao');
    final credential = provider.credential(
      idToken: token.idToken,
      accessToken: token.accessToken,
    );

    final userCredential = await _auth.signInWithCredential(credential);
    final user = userCredential.user;

    if (user == null) {
      throw Exception('Firebase user is null');
    }

    await _createOrTouchUser(
      user: user,
      provider: 'kakao',
      nickname: null,
      photoUrl: null,
    );
  }

  Future<void> signOut() => _auth.signOut();

  Future<void> _createOrTouchUser({
    required User user,
    required String provider,
    required String? nickname,
    required String? photoUrl,
  }) async {
    final firebaseRef = _db.collection('users').doc(user.uid);
    final snap = await firebaseRef.get();

    if (!snap.exists) {
      await firebaseRef.set({
        'uid': user.uid,
        'email': user.email,
        'nickname': nickname,
        'photoUrl': photoUrl,
        'category': null,
        'description': null,
        'profileCompleted': false,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'provider': provider,
        'notificationSettings': {
          'like': true,
          'comment': true,
          'chat': true,
          'meet': true,
        },
      });
      return;
    }

    await firebaseRef.update({
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}