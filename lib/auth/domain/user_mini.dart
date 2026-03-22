class UserMini {
  final String uid;
  final String nickname;
  final String? photoUrl;
  final String gender;
  final int? lastWeeklyRank;

  const UserMini({
    required this.uid,
    required this.nickname,
    required this.photoUrl,
    required this.gender,
    this.lastWeeklyRank,
  });

  factory UserMini.fromMap(Map<String, dynamic> d, String uid) {
    final lastWeeklyRankMap = d['lastWeeklyRank'] as Map<String, dynamic>?;

    int? parseRank(dynamic v) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      return null;
    }

    return UserMini(
      uid: uid,
      nickname: (d['nickname'] as String?) ?? '',
      photoUrl: d['photoUrl'] as String?,
      gender: (d['gender'] as String?) ?? '',
      lastWeeklyRank: parseRank(lastWeeklyRankMap?['rank']),
    );
  }
}
