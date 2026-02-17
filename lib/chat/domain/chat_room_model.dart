import 'package:cloud_firestore/cloud_firestore.dart';

class ChatRoomModel {
  final String id;
  final String type; // 'dm' | 'meet'
  final List<String> participantUids;
  final String? meetId;
  final String? friendStatus; // dm에서만

  const ChatRoomModel({
    required this.id,
    required this.type,
    required this.participantUids,
    required this.meetId,
    required this.friendStatus,
  });

  factory ChatRoomModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return ChatRoomModel(
      id: (d['id'] ?? doc.id).toString(),
      type: (d['type'] ?? 'dm').toString(),
      participantUids: List<String>.from(d['participantUids'] ?? const []),
      meetId: d['meetId']?.toString(),
      friendStatus: d['friendStatus']?.toString(),
    );
  }
}
