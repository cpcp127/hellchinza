enum ClaimTargetType { feed, meet, user, comment }

extension ClaimTargetTypeX on ClaimTargetType {
  String get key => switch (this) {
    ClaimTargetType.feed => 'feed',
    ClaimTargetType.meet => 'meet',
    ClaimTargetType.user => 'user',
    ClaimTargetType.comment => 'comment',
  };

  String get label => switch (this) {
    ClaimTargetType.feed => '피드',
    ClaimTargetType.meet => '모임',
    ClaimTargetType.user => '유저',
    ClaimTargetType.comment => '댓글',
  };
}

class ClaimTarget {
  final ClaimTargetType type;
  final String targetId; // feedId / meetId / userUid / commentId
  final String? targetOwnerUid; // 작성자 uid(가능하면)
  final String? title; // 피드요약/모임제목/닉네임 등
  final String? imageUrl; // 썸네일 있으면
  final String? parentId;

  const ClaimTarget({
    required this.type,
    required this.targetId,
    this.targetOwnerUid,
    this.title,
    this.imageUrl,
    this.parentId,
  });
}
