import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hellchinza/auth/domain/user_model.dart';

class RankingInitResult {
  final List<UserModel> top3;
  final int myWeeklyScore;
  final int higherCount;
  final int totalRankUsers;
  final double? topPercent;
  final DocumentSnapshot<Map<String, dynamic>>? top3LastDoc;

  const RankingInitResult({
    required this.top3,
    required this.myWeeklyScore,
    required this.higherCount,
    required this.totalRankUsers,
    required this.topPercent,
    required this.top3LastDoc,
  });
}

class RankingRepo {
  RankingRepo({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  Query<Map<String, dynamic>> get baseQuery {
    return _db
        .collection('users')
        .where('profileCompleted', isEqualTo: true)
        .orderBy('score.weekly', descending: true)
        .orderBy('uid', descending: false);
  }

  Future<RankingInitResult> fetchInitialRanking({
    required int myWeeklyScore,
  }) async {
    final top3Snap = await baseQuery.limit(3).get();
    final top3LastDoc = top3Snap.docs.isNotEmpty ? top3Snap.docs.last : null;

    final top3 = top3Snap.docs
        .map((e) => UserModel.fromFirestore(e.data()))
        .toList();

    final totalCountSnap = await _db
        .collection('users')
        .where('profileCompleted', isEqualTo: true)
        .count()
        .get();

    final higherCountSnap = await _db
        .collection('users')
        .where('profileCompleted', isEqualTo: true)
        .where('score.weekly', isGreaterThan: myWeeklyScore)
        .count()
        .get();

    final total = totalCountSnap.count ?? 0;
    final higher = higherCountSnap.count ?? 0;

    double? topPercent;
    if (total > 0) {
      topPercent = ((higher + 1) / total) * 100;
    }

    return RankingInitResult(
      top3: top3,
      myWeeklyScore: myWeeklyScore,
      higherCount: higher,
      totalRankUsers: total,
      topPercent: topPercent,
      top3LastDoc: top3LastDoc,
    );
  }

  Query<Map<String, dynamic>> buildRestQuery(
      DocumentSnapshot<Map<String, dynamic>>? top3LastDoc,
      ) {
    if (top3LastDoc == null) {
      return baseQuery.limit(20);
    }

    return baseQuery.startAfterDocument(top3LastDoc);
  }
}