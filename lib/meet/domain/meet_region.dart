class MeetRegion {
  final String code;      // 법정동코드(10자리 등)
  final String fullName;  // "서울특별시 서초구 반포동"

  const MeetRegion({
    required this.code,
    required this.fullName,
  });

  factory MeetRegion.fromJson(Map<String, dynamic> json) {
    return MeetRegion(
      code: (json['code'] as String?) ?? '',
      fullName: (json['fullName'] as String?) ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'code': code,
    'fullName': fullName,
  };

  @override
  String toString() => 'MeetRegion(code: $code, fullName: $fullName)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is MeetRegion &&
              runtimeType == other.runtimeType &&
              code == other.code;

  @override
  int get hashCode => code.hashCode;
}
