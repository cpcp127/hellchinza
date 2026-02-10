import 'package:cloud_firestore/cloud_firestore.dart';

class LightningModel {
  final String id;
  final String meetId;
  final String authorUid;

  final String title;
  final String category;

  final DateTime dateTime;

  final int maxMembers;
  final int currentMemberCount;

  final List<String> memberUids;

  final Map<String, dynamic>? place; // ✅ selectedPlace.toJson() 그대로 저장했으니 일단 map
  final List<String> imageUrls;

  final String status;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  const LightningModel({
    required this.id,
    required this.meetId,
    required this.authorUid,
    required this.title,
    required this.category,
    required this.dateTime,
    required this.maxMembers,
    required this.currentMemberCount,
    required this.memberUids,
    required this.place,
    required this.imageUrls,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  static int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v.trim()) ?? 0;
    return 0;
  }

  static DateTime? _tsToDt(dynamic v) => v is Timestamp ? v.toDate() : null;

  factory LightningModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    final memberRaw = (d['memberUids'] as List?) ?? const [];
    final imageRaw = (d['imageUrls'] as List?) ?? const [];

    return LightningModel(
      id: (d['id'] as String?) ?? doc.id,
      meetId: (d['meetId'] as String?) ?? '',
      authorUid: (d['authorUid'] as String?) ?? '',
      title: (d['title'] as String?) ?? '',
      category: (d['category'] as String?) ?? '',
      dateTime: _tsToDt(d['dateTime']) ?? DateTime.now(),
      maxMembers: _toInt(d['maxMembers']),
      currentMemberCount: _toInt(d['currentMemberCount']),
      memberUids: memberRaw.whereType<String>().toList(),
      place: (d['place'] is Map) ? Map<String, dynamic>.from(d['place']) : null,
      imageUrls: imageRaw.map((e) => e.toString()).toList(),
      status: (d['status'] as String?) ?? 'open',
      createdAt: _tsToDt(d['createdAt']),
      updatedAt: _tsToDt(d['updatedAt']),
    );
  }

  bool get isFull => currentMemberCount >= maxMembers;
}
