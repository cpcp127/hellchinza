// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'feed_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

FeedModel _$FeedModelFromJson(Map<String, dynamic> json) => FeedModel(
  id: json['id'] as String,
  authorUid: json['authorUid'] as String,
  mainType: json['mainType'] as String,
  subType: json['subType'] as String?,
  contents: json['contents'] as String?,
  imageUrls: (json['imageUrls'] as List<dynamic>?)
      ?.map((e) => e as String)
      .toList(),
  likeUids: (json['likeUids'] as List<dynamic>)
      .map((e) => e as String)
      .toList(),
  poll: json['poll'] == null
      ? null
      : PollModel.fromJson(json['poll'] as Map<String, dynamic>),
  createdAt: FeedModel._timestampFromJson(json['createdAt']),
  updatedAt: FeedModel._timestampFromJson(json['updatedAt']),
  meetId: json['meetId'] as String?,
  place: json['place'] == null
      ? null
      : FeedPlace.fromJson(json['place'] as Map<String, dynamic>),
  commentCount: (json['commentCount'] as num).toInt(),
);

Map<String, dynamic> _$FeedModelToJson(FeedModel instance) => <String, dynamic>{
  'id': instance.id,
  'authorUid': instance.authorUid,
  'mainType': instance.mainType,
  'subType': instance.subType,
  'contents': instance.contents,
  'place': instance.place?.toJson(),
  'imageUrls': instance.imageUrls,
  'likeUids': instance.likeUids,
  'poll': instance.poll?.toJson(),
  'commentCount': instance.commentCount,
  'meetId': instance.meetId,
  'createdAt': FeedModel._timestampToJson(instance.createdAt),
  'updatedAt': FeedModel._timestampToJson(instance.updatedAt),
};
