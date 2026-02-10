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
}
