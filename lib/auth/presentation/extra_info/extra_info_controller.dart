import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:hellchinza/auth/presentation/extra_info/extra_info_state.dart';

final extraInfoControllerProvider =
StateNotifierProvider.autoDispose<ExtraInfoController, ExtraInfoState>((ref) {
  return ExtraInfoController(ref);
});

class ExtraInfoController extends StateNotifier<ExtraInfoState> {
  final Ref ref;

  ExtraInfoController(this.ref) : super(ExtraInfoState());


  void onChangeNickname(String nickname){
    state = state.copyWith(nickname: nickname);
  }

  void onChangeNicknameErrorText(String errorText){
    state = state.copyWith(nicknameErrorText: errorText);
  }

  void submitNickname(GlobalKey<FormState> formKey) {
    final isValid = formKey.currentState?.validate() ?? false;

    if (!isValid) {
      // ❌ 검증 실패 → 아무것도 안 함 (에러는 TextFormField가 표시)
      return;
    }else{
      FocusManager.instance.primaryFocus?.unfocus();
      state = state.copyWith(currentIndex: 1);
    }

    // ✅ 검증 통과
    // 다음 단계 로직 실행
    // 예: Firestore 저장, 다음 페이지 이동 등
  }

  void toggleCategory(String category) {
    final current = state.selectedCategory ?? [];

    final List<String> updated = List.from(current);

    if (updated.contains(category)) {
      // ✅ 이미 선택 → 제거
      updated.remove(category);
    } else {
      // ✅ 미선택 → 추가
      updated.add(category);
    }

    state = state.copyWith(selectedCategory: updated);
  }

  Future<void> completeSignup() async {
    state = state.copyWith(isLoading: true);
    try{
     final user = FirebaseAuth.instance.currentUser;

      // ✅ Firestore upsert
      final firebaseRef = FirebaseFirestore.instance.collection('users').doc(user!.uid);
      await firebaseRef.update({
        'category':state.selectedCategory!,
        'nickname': state.nickname,
        'profileCompleted': true,

      });

    }catch(e){
      print('에러 발생');
      state = state.copyWith(isLoading: false);
    }

  }

  void prevStep() {
    if (state.currentIndex <= 0) return;
    state = state.copyWith(currentIndex: state.currentIndex - 1);
  }
}
