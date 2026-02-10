class UserMini {
  final String uid;
  final String nickname;
  final String? photoUrl;

  const UserMini({
    required this.uid,
    required this.nickname,
    required this.photoUrl,
  });

  factory UserMini.fromDoc(String uid, Map<String, dynamic> d) {
    return UserMini(
      uid: uid,
      nickname: (d['nickname'] as String?) ?? '',
      photoUrl: d['photoUrl'] as String?,
    );
  }
}
