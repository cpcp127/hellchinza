// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'poll_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PollModel _$PollModelFromJson(Map<String, dynamic> json) => PollModel(
  options: (json['options'] as List<dynamic>)
      .map((e) => PollOptionModel.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$PollModelToJson(PollModel instance) => <String, dynamic>{
  'options': instance.options,
};

PollOptionModel _$PollOptionModelFromJson(Map<String, dynamic> json) =>
    PollOptionModel(
      id: json['id'] as String,
      text: json['text'] as String,
      voterUids: (json['voterUids'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
    );

Map<String, dynamic> _$PollOptionModelToJson(PollOptionModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'text': instance.text,
      'voterUids': instance.voterUids,
    };
