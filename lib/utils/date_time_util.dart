import 'package:cloud_firestore/cloud_firestore.dart';

class DateTimeUtil {
  DateTimeUtil._(); // 인스턴스 생성 방지

  /// Firestore Timestamp / DateTime / null → DateTime
  static DateTime parse(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is DateTime) {
      return value;
    }
    return DateTime.now();
  }

  /// 상대 시간 포맷 (한국어)
  static String formatRelative(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);

    if (diff.inSeconds < 60) {
      return '방금';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}분 전';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}시간 전';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}일 전';
    } else if (diff.inDays < 30) {
      final weeks = (diff.inDays / 7).floor();
      return '${weeks}주 전';
    } else if (diff.inDays < 365) {
      final months = (diff.inDays / 30).floor();
      return '${months}개월 전';
    } else {
      final years = (diff.inDays / 365).floor();
      return '${years}년 전';
    }
  }

  /// Firestore 값 바로 넣어도 되는 헬퍼
  static String from(dynamic value) {
    return formatRelative(parse(value));
  }

  static String formatMonthTimeDateTime(DateTime dateTime) {
    final month = dateTime.month;
    final day = dateTime.day;
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');

    return '$month월 $day일 $hour:$minute';
  }

  static String dateKey(DateTime d) {
    final dd = DateTime(d.year, d.month, d.day);
    final y = dd.year.toString().padLeft(4, '0');
    final m = dd.month.toString().padLeft(2, '0');
    final day = dd.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  static DateTime startOfWeekMonday(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    final diff = (d.weekday + 6) % 7; // Mon=0
    final monday = d.subtract(Duration(days: diff));
    return DateTime(monday.year, monday.month, monday.day);
  }



  static String weekdayKo(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return '월';
      case DateTime.tuesday:
        return '화';
      case DateTime.wednesday:
        return '수';
      case DateTime.thursday:
        return '목';
      case DateTime.friday:
        return '금';
      case DateTime.saturday:
        return '토';
      case DateTime.sunday:
      default:
        return '일';
    }
  }

  static bool isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

 static String dayKey(DateTime d) {
    String p2(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${p2(d.month)}-${p2(d.day)}';
  }



  static String weekKey(DateTime anyDay) {
    final w = startOfWeekMonday(anyDay);
    return dayKey(w); // "YYYY-MM-DD"
  }

  static DateTime startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);
}
