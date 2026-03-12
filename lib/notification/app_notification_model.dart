import 'package:cloud_firestore/cloud_firestore.dart';

class AppNotificationModel {
  final String id;
  final String type;
  final bool isRead;
  final String? feedId;
  final String? commentId;
  final String? senderUid;
  final String? senderNickname;
  final String? title;
  final String? body;
  final String? contentPreview;
  final DateTime? createdAt;
  final String? action;
  final String? meetId;

  AppNotificationModel({
    required this.id,
    required this.type,
    required this.isRead,
    this.feedId,
    this.commentId,
    this.senderUid,
    this.senderNickname,
    this.title,
    this.body,
    this.contentPreview,
    this.createdAt,
    this.action,
    this.meetId,
  });

  factory AppNotificationModel.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    return AppNotificationModel(
      id: doc.id,
      type: (data['type'] ?? '').toString(),
      isRead: (data['isRead'] ?? false) as bool,
      feedId: data['feedId']?.toString(),
      commentId: data['commentId']?.toString(),
      senderUid: data['senderUid']?.toString(),
      senderNickname: data['senderNickname']?.toString(),
      title: data['title']?.toString(),
      body: data['body']?.toString(),
      contentPreview: data['contentPreview']?.toString(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      action: (data['action'] ?? '').toString(),
      meetId: (data['meetId'] ?? '').toString(),
    );
  }
}
