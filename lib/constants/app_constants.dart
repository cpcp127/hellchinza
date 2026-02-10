
import 'package:flutter/material.dart';

const List<String> workList = [
  '헬스',
  '클라이밍',
  '볼링',
  '테니스',
  '스쿼시',
  '배드민턴',
  '런닝',
  '사이클',
  '풋살/축구',
  '수영',
  '다이어트',
  '골프',
  '필라테스',
  '요가',
  '탁구',
  '당구',
  '복싱',
  '주짓수',
  '보드',
  '기타',
];

enum FeedMainType { owunwan, diet, question, review }

extension FeedMainTypeX on FeedMainType {
  String get label {
    switch (this) {
      case FeedMainType.owunwan:
        return '오운완';
      case FeedMainType.diet:
        return '식단';
      case FeedMainType.question:
        return '질문';
      case FeedMainType.review:
        return '후기';
    }
  }

  IconData get icon {
    switch (this) {
      case FeedMainType.owunwan:
        return Icons.fitness_center;
      case FeedMainType.diet:
        return Icons.restaurant_outlined;
      case FeedMainType.question:
        return Icons.help_outline;
      case FeedMainType.review:
        return Icons.rate_review_outlined;
    }
  }
}