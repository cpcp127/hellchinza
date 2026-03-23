import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'package:hellchinza/auth/presentation/extra_info/extra_info_state.dart';
import 'package:hellchinza/auth/providers/auth_provider.dart';
import 'package:hellchinza/auth/providers/user_provider.dart';

class ExtraInfoController extends StateNotifier<ExtraInfoState> {
  ExtraInfoController(this.ref) : super(const ExtraInfoState());

  final Ref ref;

  void onChangeNickname(String nickname) {
    state = state.copyWith(
      nickname: nickname,
      clearNicknameError: true,
      clearError: true,
    );
  }

  void onChangeNicknameErrorText(String errorText) {
    state = state.copyWith(nicknameErrorText: errorText);
  }

  void submitNickname(GlobalKey<FormState> formKey) {
    final isValid = formKey.currentState?.validate() ?? false;
    if (!isValid) return;

    FocusManager.instance.primaryFocus?.unfocus();
    state = state.copyWith(currentIndex: 1, clearNicknameError: true);
  }

  void toggleCategory(String category) {
    final updated = List<String>.from(state.selectedCategory);

    if (updated.contains(category)) {
      updated.remove(category);
    } else {
      updated.add(category);
    }

    state = state.copyWith(selectedCategory: updated);
  }

  Future<void> completeSignup() async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      await ref.read(userRepoProvider).updateExtraInfo(
        nickname: state.nickname,
        category: state.selectedCategory,
        gender: state.gender ?? '',
      );
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
      rethrow;
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }

  void prevStep() {
    if (state.currentIndex <= 0) return;
    state = state.copyWith(currentIndex: state.currentIndex - 1);
  }

  void onSelectGender(String gender) {
    state = state.copyWith(gender: gender);
  }

  void submitGender() {
    state = state.copyWith(currentIndex: 2);
  }

  Future<void> back() async {
    if (state.currentIndex == 0) {
      await ref.read(authRepoProvider).signOut();
      return;
    }
    prevStep();
  }
}