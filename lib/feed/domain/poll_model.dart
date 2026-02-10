import 'package:json_annotation/json_annotation.dart';

part 'poll_model.g.dart';

@JsonSerializable()
class PollModel {
  final List<PollOptionModel> options;

  const PollModel({
    required this.options,
  });

  factory PollModel.fromJson(Map<String, dynamic> json) =>
      _$PollModelFromJson(json);

  Map<String, dynamic> toJson() => _$PollModelToJson(this);
}

@JsonSerializable()
class PollOptionModel {
  final String id;
  final String text;
  final List<String> voterUids;

  const PollOptionModel({
    required this.id,
    required this.text,
    required this.voterUids,
  });

  factory PollOptionModel.fromJson(Map<String, dynamic> json) =>
      _$PollOptionModelFromJson(json);

  Map<String, dynamic> toJson() => _$PollOptionModelToJson(this);
}