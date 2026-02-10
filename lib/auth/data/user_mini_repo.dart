import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../domain/user_mini.dart';

class UserMiniRepo {
  UserMiniRepo(this._db);

  final FirebaseFirestore _db;

  // 메모리 캐시
  final _cache = <String, UserMini?>{};
  final _inflight = <String, Future<UserMini?>>{};

  Future<UserMini?> getUserMini(String uid, {bool forceRefresh = false}) {
    if (!forceRefresh && _cache.containsKey(uid)) {
      return Future.value(_cache[uid]);
    }

    // 동시에 같은 uid 여러번 호출되면 1번만 요청
    final existing = _inflight[uid];
    if (existing != null) return existing;

    final fut = _db.collection('users').doc(uid).get().then((doc) {
      final mini = doc.exists ? UserMini.fromMap(doc.data()!,doc.id) : null;
      _cache[uid] = mini;
      return mini;
    }).whenComplete(() {
      _inflight.remove(uid);
    });

    _inflight[uid] = fut;
    return fut;
  }

  void clear(String uid) => _cache.remove(uid);
  void clearAll() => _cache.clear();
}
