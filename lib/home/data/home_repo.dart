import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:hellchinza/auth/domain/user_model.dart';

class HomeRepo {
  HomeRepo(this._db, this._auth);

  final FirebaseFirestore _db;
  final fb_auth.FirebaseAuth _auth;

  String? get currentUid => _auth.currentUser?.uid;

  String get currentUidOrThrow {
    final uid = _auth.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      throw Exception('로그인이 필요합니다');
    }
    return uid;
  }

  Future<UserModel?> fetchUser(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists) return null;

    final data = doc.data();
    if (data == null) return null;

    return UserModel.fromFirestore(data);
  }

  Stream<bool> hasUnreadNotificationStream() {
    final uid = currentUid;
    if (uid == null) return Stream.value(false);

    return _db
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .where('isRead', isEqualTo: false)
        .limit(1)
        .snapshots()
        .map((snap) => snap.docs.isNotEmpty);
  }
}
