class UserMini {
  final String uid;
  final String nickname;
  final String? photoUrl;

  const UserMini({
    required this.uid,
    required this.nickname,
    required this.photoUrl,
  });

  factory UserMini.fromMap(Map<String, dynamic> d, String uid) {
    return UserMini(
      uid: uid,
      nickname: (d['nickname'] as String?) ?? '',
      photoUrl: (d['photoUrl'] as String?),
    );
  }
}
