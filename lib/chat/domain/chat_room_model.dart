import 'package:cloud_firestore/cloud_firestore.dart';

class ChatRoomModel {
  final String id;
  final String type; // 'dm' | 'group'
  final List<String> userUids;
  final List<String> visibleUids;
  final String? meetId;
  final String? title;
  final String? lastMessageText;
  final String? lastMessageType;
  final DateTime? lastMessageAt;
  final Map<String, dynamic> unreadCountMap;
  final Map<String, dynamic> activeAtMap;
  final bool allowMessages;

  const ChatRoomModel({
    required this.id,
    required this.type,
    required this.userUids,
    required this.visibleUids,
    required this.meetId,
    required this.title,
    required this.lastMessageText,
    required this.lastMessageType,
    required this.lastMessageAt,
    required this.unreadCountMap,
    required this.activeAtMap,
    required this.allowMessages,
  });

  factory ChatRoomModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};

    DateTime? toDate(dynamic v) {
      if (v is Timestamp) return v.toDate();
      if (v is DateTime) return v;
      return null;
    }

    return ChatRoomModel(
      id: (d['id'] ?? doc.id).toString(),
      type: (d['type'] ?? 'dm').toString(),
      userUids: List<String>.from(d['userUids'] ?? const []),
      visibleUids: List<String>.from(d['visibleUids'] ?? const []),
      meetId: d['meetId']?.toString(),
      title: d['title']?.toString(),
      lastMessageText: d['lastMessageText']?.toString(),
      lastMessageType: d['lastMessageType']?.toString(),
      lastMessageAt: toDate(d['lastMessageAt']),
      unreadCountMap:
          (d['unreadCountMap'] as Map?)?.cast<String, dynamic>() ??
          const <String, dynamic>{},
      activeAtMap:
          (d['activeAtMap'] as Map?)?.cast<String, dynamic>() ??
          const <String, dynamic>{},
      allowMessages: (d['allowMessages'] ?? false) == true,
    );
  }
}
