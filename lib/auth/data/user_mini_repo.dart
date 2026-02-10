import 'package:cloud_firestore/cloud_firestore.dart';
import '../domain/user_mini.dart';

class UserMiniRepo {
  UserMiniRepo(this._db);

  final FirebaseFirestore _db;

  // ✅ 메모리 캐시 (앱 실행 중 유지)
  final Map<String, UserMini?> _cache = {};

  // ✅ 중복 요청 방지용 (동시에 같은 uid 요청 들어올 때 1번만 네트워크)
  final Map<String, Future<UserMini?>> _inflight = {};

  Future<UserMini?> getUserMiniOnce(String uid) {
    // 1) 캐시 hit
    if (_cache.containsKey(uid)) {
      return Future.value(_cache[uid]);
    }

    // 2) inflight hit
    if (_inflight.containsKey(uid)) {
      return _inflight[uid]!;
    }

    // 3) 실제 fetch
    final fut = _db.collection('users').doc(uid).get().then((doc) {
      if (!doc.exists) {
        _cache[uid] = null;
        return null;
      }
      final data = doc.data();
      final mini = data == null ? null : UserMini.fromMap(data, uid);
      _cache[uid] = mini;
      return mini;
    }).catchError((_) {
      // 실패 시엔 캐시 저장 X (다음에 다시 시도 가능)
      return null;
    }).whenComplete(() {
      _inflight.remove(uid);
    });

    _inflight[uid] = fut;
    return fut;
  }

  // (선택) 프로필 수정 등에서 캐시 갱신하고 싶을 때
  void upsertCache(UserMini mini) {
    _cache[mini.uid] = mini;
  }

  void clearCache(String uid) {
    _cache.remove(uid);
  }

  void clearAll() {
    _cache.clear();
  }
}
