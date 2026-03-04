class WeekOowStat {
  final DateTime weekStartMonday; // 월요일 00:00
  final int doneDays; // 그 주에 "오운완 올린 날" 수(중복 제거)
  final bool achieved; // doneDays >= target

  const WeekOowStat({
    required this.weekStartMonday,
    required this.doneDays,
    required this.achieved,
  });
}