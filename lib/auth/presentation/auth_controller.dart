import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'package:hellchinza/auth/presentation/auth_state.dart';

import '../providers/auth_provider.dart';

class AuthController extends StateNotifier<AuthState> {
  AuthController(this.ref) : super(const AuthState());

  final Ref ref;

  void onChangeNickname(String nickname) {
    state = state.copyWith(nickname: nickname);
  }

  void submitNickname(GlobalKey<FormState> formKey) {
    final isValid = formKey.currentState?.validate() ?? false;
    if (!isValid) return;
  }

  Future<void> signInWithApple() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await ref.read(authRepoProvider).signInWithApple();
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
      rethrow;
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> signInWithGoogle() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await ref.read(authRepoProvider).signInWithGoogle();
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
      rethrow;
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> signInWithKakao() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await ref.read(authRepoProvider).signInWithKakao();
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
      rethrow;
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }
}