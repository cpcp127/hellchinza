import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/legacy.dart';

class UserNotifier extends StateNotifier<UserModel> {
  UserNotifier()
      : super(
    const UserModel(
      uid: '',
      email: '',
      nickname: '',
      profileCompleted: false,
    ),
  );

  Future<void> updateUserModel(UserModel userModel) async {
    state = userModel;
  }

  Future<void> resetUserModel() async {
    state = const UserModel(
      uid: '',
      email: '',
      nickname: '',
      profileCompleted: false,
    );
  }
}

final myUserModelProvider = StateNotifierProvider<UserNotifier, UserModel>((
    ref,
    ) {
  return UserNotifier();
});

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

  // ✅ 추가
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

  factory UserModel.fromFirestore(Map<String, dynamic> json) {
    DateTime? _toDate(dynamic v) {
      if (v == null) return null;
      if (v is Timestamp) return v.toDate();
      if (v is DateTime) return v;
      return null;
    }

    int? _parseGoal(dynamic goal) {
      if (goal is int) return goal;
      if (goal is num) return goal.toInt();
      return null;
    }

    int _parseInt(dynamic v) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      return 0;
    }

    int? _parseNullableInt(dynamic v) {
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
      createdAt: _toDate(json['createdAt']),
      updatedAt: _toDate(json['updatedAt']),
      gender: json['gender'] as String?,
      workoutGoal: _parseGoal(goalMap?['weeklyTarget']),
      scoreTotal: _parseInt(scoreMap?['total']),
      scoreWeekly: _parseInt(scoreMap?['weekly']),

      // ✅ 추가
      lastWeeklyRank: _parseNullableInt(lastWeeklyRankMap?['rank']),
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

    // ✅ 추가
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