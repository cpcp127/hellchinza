import 'package:cloud_firestore/cloud_firestore.dart';

import '../../feed/create_feed/create_feed_state.dart';

class MeetSummary {
  final String id;
  final String title;
  final String? category;


  final int maxMembers;
  final int currentMemberCount;

  final List<dynamic>? imageUrls;


  MeetSummary({
    required this.id,
    required this.title,

    required this.maxMembers,
    required this.currentMemberCount,
    this.category,
    this.imageUrls,

  });

  factory MeetSummary.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return MeetSummary(
      id: doc.id,
      title: (data['title'] ?? '') as String,
      category: data['category'] as String?,

      maxMembers: (data['maxMembers'] ?? 0) as int,
      currentMemberCount: (data['currentMemberCount'] ?? 0) as int,
      imageUrls: data['imageUrls'] as List<dynamic>?,

    );
  }
}
