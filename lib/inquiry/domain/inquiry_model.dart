import 'package:cloud_firestore/cloud_firestore.dart';

class InquiryModel {
  final String id;
  final String authorUid;
  final String message;
  final String status;
  final List<String> imageUrls;
  final String? answer;
  final DateTime? createdAt;
  final DateTime? answeredAt;

  const InquiryModel({
    required this.id,
    required this.authorUid,
    required this.message,
    required this.status,
    required this.imageUrls,
    this.answer,
    this.createdAt,
    this.answeredAt,
  });

  factory InquiryModel.fromJson(Map<String, dynamic> json) {
    return InquiryModel(
      id: json['id'] ?? '',
      authorUid: json['authorUid'] ?? '',
      message: json['message'] ?? '',
      status: json['status'] ?? 'open',
      imageUrls:
      (json['imageUrls'] as List?)?.map((e) => e.toString()).toList() ??
          [],
      answer: json['answer'],
      createdAt: _toDate(json['createdAt']),
      answeredAt: _toDate(json['answeredAt']),
    );
  }

  static DateTime? _toDate(dynamic v) {
    if (v is Timestamp) return v.toDate();
    return null;
  }
}