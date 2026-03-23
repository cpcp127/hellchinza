import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hellchinza/auth/domain/user_mini.dart';
import 'package:hellchinza/auth/domain/user_model.dart';

class UserRepo {
  UserRepo(this._db, this._auth);

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  final _miniCache = <String, UserMini?>{};
  final _miniInflight = <String, Future<UserMini?>>{};

  Future<UserMini?> getUserMini(String uid, {bool forceRefresh = false}) {
    if (!forceRefresh && _miniCache.containsKey(uid)) {
      return Future.value(_miniCache[uid]);
    }

    final existing = _miniInflight[uid];
    if (existing != null) return existing;

    final future = _db
        .collection('users')
        .doc(uid)
        .get()
        .then((doc) {
          final mini = doc.exists && doc.data() != null
              ? UserMini.fromMap(doc.data()!, doc.id)
              : null;
          _miniCache[uid] = mini;
          return mini;
        })
        .whenComplete(() {
          _miniInflight.remove(uid);
        });

    _miniInflight[uid] = future;
    return future;
  }

  Future<UserModel?> getMyUser() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    final doc = await _db.collection('users').doc(user.uid).get();
    if (!doc.exists || doc.data() == null) return null;

    return UserModel.fromFirestore(doc.data()!);
  }

  Future<void> updateExtraInfo({
    required String nickname,
    required List<String> category,
    required String gender,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('현재 로그인한 유저가 없습니다.');
    }

    await _db.collection('users').doc(user.uid).update({
      'category': category,
      'nickname': nickname,
      'profileCompleted': true,
      'gender': gender,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    clear(user.uid);
  }

  Future<void> updateMyUserModel(UserModel userModel) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('현재 로그인한 유저가 없습니다.');
    }

    await _db
        .collection('users')
        .doc(user.uid)
        .set(userModel.toFirestore(), SetOptions(merge: true));

    clear(user.uid);
  }

  void clear(String uid) => _miniCache.remove(uid);

  void clearAll() => _miniCache.clear();
}
