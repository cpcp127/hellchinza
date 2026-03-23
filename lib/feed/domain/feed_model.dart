import 'package:cloud_firestore/cloud_firestore.dart';

import 'feed_place.dart';
import 'poll_model.dart';

enum FeedMainType {
  workout('오운완'),
  meal('식단'),
  question('질문'),
  review('후기');

  final String label;

  const FeedMainType(this.label);
}

class FeedVisibility {
  static const String public = 'public';
  static const String friends = 'friends';
}

class FeedModel {
  final String id;
  final String authorUid;
  final String mainType;
  final String? subType;
  final String? contents;
  final FeedPlace? place;
  final List<String> imageUrls;
  final String visibility;
  final PollModel? poll;
  final int commentCount;
  final String? meetId;
  final DateTime createdAt;
  final DateTime updatedAt;

  const FeedModel({
    required this.id,
    required this.authorUid,
    required this.mainType,
    this.subType,
    this.contents,
    this.place,
    this.imageUrls = const [],
    this.visibility = FeedVisibility.public,
    this.poll,
    required this.commentCount,
    this.meetId,
    required this.createdAt,
    required this.updatedAt,
  });

  factory FeedModel.fromJson(Map<String, dynamic> json) {
    return FeedModel(
      id: (json['id'] ?? '') as String,
      authorUid: (json['authorUid'] ?? '') as String,
      mainType: (json['mainType'] ?? '') as String,
      subType: json['subType'] as String?,
      contents: json['contents'] as String?,
      place: json['place'] == null
          ? null
          : FeedPlace.fromJson(Map<String, dynamic>.from(json['place'])),
      imageUrls:
          (json['imageUrls'] as List?)?.map((e) => e.toString()).toList() ??
          const [],
      visibility: (json['visibility'] as String?) ?? FeedVisibility.public,
      poll: json['poll'] == null
          ? null
          : PollModel.fromJson(Map<String, dynamic>.from(json['poll'])),
      commentCount: ((json['commentCount'] ?? 0) as num).toInt(),
      meetId: json['meetId'] as String?,
      createdAt: _timestampFromJson(json['createdAt']),
      updatedAt: _timestampFromJson(json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'authorUid': authorUid,
    'mainType': mainType,
    'subType': subType,
    'contents': contents,
    'place': place?.toJson(),
    'imageUrls': imageUrls.isEmpty ? null : imageUrls,
    'visibility': visibility,
    'poll': poll?.toJson(),
    'commentCount': commentCount,
    'meetId': meetId,
    'createdAt': Timestamp.fromDate(createdAt),
    'updatedAt': Timestamp.fromDate(updatedAt),
  };

  static DateTime _timestampFromJson(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.fromMillisecondsSinceEpoch(0);
  }
}
