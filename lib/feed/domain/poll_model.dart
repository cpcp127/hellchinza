class PollModel {
  final List<PollOptionModel> options;

  const PollModel({required this.options});

  factory PollModel.fromJson(Map<String, dynamic> json) {
    final raw = (json['options'] as List?) ?? const [];
    return PollModel(
      options: raw
          .map((e) => PollOptionModel.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'options': options.map((e) => e.toJson()).toList(),
  };
}

class PollOptionModel {
  final String id;
  final String text;
  final List<String> voterUids;

  const PollOptionModel({
    required this.id,
    required this.text,
    required this.voterUids,
  });

  factory PollOptionModel.fromJson(Map<String, dynamic> json) {
    return PollOptionModel(
      id: (json['id'] ?? '') as String,
      text: (json['text'] ?? '') as String,
      voterUids:
          (json['voterUids'] as List?)?.map((e) => e.toString()).toList() ??
          const [],
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'text': text,
    'voterUids': voterUids,
  };
}
