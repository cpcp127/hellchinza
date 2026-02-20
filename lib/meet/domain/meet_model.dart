import 'package:cloud_firestore/cloud_firestore.dart';

import 'meet_region.dart';



class MeetModel {
  final String id;
  final String authorUid;
  final String title;
  final String intro;
  final String category;
  final List<MeetRegion> regions;

  final int maxMembers;
  final int currentMemberCount;
  final bool needApproval;
  final List<String> userUids;
  final String status;

  final List<String> imageUrls;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  const MeetModel({
    required this.id,
    required this.authorUid,
    required this.title,
    required this.intro,
    required this.category,
    required this.regions,
    required this.maxMembers,
    required this.currentMemberCount,
    required this.needApproval,
    required this.userUids,
    required this.status,
    required this.imageUrls,
    required this.createdAt,
    required this.updatedAt,
  });

  factory MeetModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    final regionsRaw = (d['regions'] as List?) ?? [];
    final imageRaw = (d['imageUrls'] as List?) ?? [];

    DateTime? tsToDt(dynamic v) =>
        v is Timestamp ? v.toDate() : null;

    return MeetModel(
      id: (d['id'] as String?) ?? doc.id,
      authorUid: (d['authorUid'] as String?) ?? '',
      title: (d['title'] as String?) ?? '',
      intro: (d['intro'] as String?) ?? '',
      category: (d['category'] as String?) ?? '',
      regions: regionsRaw
          .whereType<Map>()
          .map((e) => MeetRegion.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      maxMembers: (d['maxMembers'] as num?)?.toInt() ?? 0,
      currentMemberCount: (d['currentMemberCount'] as num?)?.toInt() ?? 0,
      needApproval: (d['needApproval'] as bool?) ?? false,
      userUids: List<String>.from(d['userUids'] ?? const []),
      status: (d['status'] as String?) ?? 'open',
      imageUrls: imageRaw.map((e) => e.toString()).toList(),
      createdAt: tsToDt(d['createdAt']),
      updatedAt: tsToDt(d['updatedAt']),
    );
  }
}
