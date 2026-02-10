import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hellchinza/feed/domain/poll_model.dart';
import 'package:json_annotation/json_annotation.dart';

import '../create_feed/create_feed_state.dart';

part 'feed_model.g.dart';

@JsonSerializable(explicitToJson: true)
class FeedModel {
  final String id;
  final String authorUid;
  final String mainType;
  final String? subType;
  final String? contents;
  final FeedPlace? place;
  /// 이미지 없으면 null
  final List<String>? imageUrls;

  /// 좋아요 누른 유저 uid 목록
  final List<String> likeUids;

  /// 투표 (없으면 null)
  final PollModel? poll;
  final int commentCount;
  final String? meetId;
  @JsonKey(
    fromJson: _timestampFromJson,
    toJson: _timestampToJson,
  )
  final DateTime createdAt;

  @JsonKey(
    fromJson: _timestampFromJson,
    toJson: _timestampToJson,
  )
  final DateTime updatedAt;

  const FeedModel({
    required this.id,
    required this.authorUid,
    required this.mainType,
    this.subType,
    this.contents,
    this.imageUrls,
    required this.likeUids,
    this.poll,
    required this.createdAt,
    required this.updatedAt,
    this.meetId,
    this.place,required this.commentCount
  });

  /// Firestore → Model
  factory FeedModel.fromJson(Map<String, dynamic> json) =>
      _$FeedModelFromJson(json);

  /// Model → Firestore
  Map<String, dynamic> toJson() => _$FeedModelToJson(this);

  // ---------- Timestamp helpers ----------
  static DateTime _timestampFromJson(dynamic value) {
    if (value == null) return DateTime.fromMillisecondsSinceEpoch(0);
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  static dynamic _timestampToJson(DateTime value) {
    return Timestamp.fromDate(value);
  }
}
