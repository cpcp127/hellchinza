import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/legacy.dart';

class UserNotifier extends StateNotifier<UserModel> {
  UserNotifier()
    : super(
        UserModel(uid: '', email: '', nickname: '', profileCompleted: false),
      );

  Future<void> updateUserModel(UserModel userModel) async {
    state = userModel;
  }

  Future<void> resetUserModel() async {
    state = UserModel(
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

  // ✅ 추가
  final int? workoutGoal;

  const UserModel({
    required this.uid,
    required this.email,
    required this.nickname,
    this.photoUrl,
    this.description,
    this.category = const [],
    required this.profileCompleted,
    this.createdAt,
    this.updatedAt,

    // ✅ 추가
    this.workoutGoal,
  });

  factory UserModel.fromFirestore(Map<String, dynamic> json) {
    DateTime? _toDate(dynamic v) {
      if (v == null) return null;
      if (v is Timestamp) return v.toDate();
      if (v is DateTime) return v;
      return null;
    }

    // ✅ workoutGoal 파싱
    int? _parseGoal(dynamic goal) {
      if (goal is int) return goal;
      if (goal is num) return goal.toInt();
      return null;
    }

    final goalMap = json['workoutGoal'] as Map?;

    return UserModel(
      uid: (json['uid'] ?? '') as String,
      email: (json['email'] ?? '') as String,
      nickname: json['nickname'] as String,
      photoUrl: json['photoUrl'] as String?,
      description: json['description'] as String?,
      category:
      (json['category'] as List?)?.map((e) => e.toString()).toList() ??
          const [],
      profileCompleted: (json['profileCompleted'] as bool?) ?? false,
      createdAt: _toDate(json['createdAt']),
      updatedAt: _toDate(json['updatedAt']),

      // ✅ 여기
      workoutGoal: _parseGoal(goalMap?['weeklyTarget']),
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
}
