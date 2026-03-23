import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String email;
  final String nickname;
  final String? photoUrl;
  final String? description;
  final List<String> category;
  final bool profileCompleted;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final int? workoutGoal;
  final int scoreTotal;
  final int scoreWeekly;
  final String? gender;
  final int? lastWeeklyRank;

  const UserModel({
    required this.uid,
    required this.email,
    required this.nickname,
    this.photoUrl,
    this.description,
    this.category = const [],
    required this.profileCompleted,
    this.gender,
    this.createdAt,
    this.updatedAt,
    this.workoutGoal,
    this.scoreTotal = 0,
    this.scoreWeekly = 0,
    this.lastWeeklyRank,
  });

  factory UserModel.empty() {
    return const UserModel(
      uid: '',
      email: '',
      nickname: '',
      profileCompleted: false,
    );
  }

  factory UserModel.fromFirestore(Map<String, dynamic> json) {
    DateTime? toDate(dynamic v) {
      if (v == null) return null;
      if (v is Timestamp) return v.toDate();
      if (v is DateTime) return v;
      return null;
    }

    int? parseGoal(dynamic goal) {
      if (goal is int) return goal;
      if (goal is num) return goal.toInt();
      return null;
    }

    int parseInt(dynamic v) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      return 0;
    }

    int? parseNullableInt(dynamic v) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      return null;
    }

    final goalMap = json['workoutGoal'] as Map?;
    final scoreMap = json['score'] as Map?;
    final lastWeeklyRankMap = json['lastWeeklyRank'] as Map?;

    return UserModel(
      uid: (json['uid'] ?? '') as String,
      email: (json['email'] ?? '') as String,
      nickname: (json['nickname'] ?? '') as String,
      photoUrl: json['photoUrl'] as String?,
      description: json['description'] as String?,
      category:
          (json['category'] as List?)?.map((e) => e.toString()).toList() ??
          const [],
      profileCompleted: (json['profileCompleted'] as bool?) ?? false,
      createdAt: toDate(json['createdAt']),
      updatedAt: toDate(json['updatedAt']),
      gender: json['gender'] as String?,
      workoutGoal: parseGoal(goalMap?['weeklyTarget']),
      scoreTotal: parseInt(scoreMap?['total']),
      scoreWeekly: parseInt(scoreMap?['weekly']),
      lastWeeklyRank: parseNullableInt(lastWeeklyRankMap?['rank']),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'uid': uid,
    'email': email,
    'nickname': nickname,
    'photoUrl': photoUrl,
    'description': description,
    'category': category,
    'profileCompleted': profileCompleted,
    'createdAt': createdAt,
    'updatedAt': updatedAt,
    'gender': gender,
  };

  UserModel copyWith({
    String? uid,
    String? email,
    String? nickname,
    String? photoUrl,
    String? description,
    List<String>? category,
    bool? profileCompleted,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? workoutGoal,
    int? scoreTotal,
    int? scoreWeekly,
    String? gender,
    int? lastWeeklyRank,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      nickname: nickname ?? this.nickname,
      photoUrl: photoUrl ?? this.photoUrl,
      description: description ?? this.description,
      category: category ?? this.category,
      profileCompleted: profileCompleted ?? this.profileCompleted,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      workoutGoal: workoutGoal ?? this.workoutGoal,
      scoreTotal: scoreTotal ?? this.scoreTotal,
      scoreWeekly: scoreWeekly ?? this.scoreWeekly,
      gender: gender ?? this.gender,
      lastWeeklyRank: lastWeeklyRank ?? this.lastWeeklyRank,
    );
  }
}
