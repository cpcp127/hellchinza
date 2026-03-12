import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../services/snackbar_service.dart';
import 'withdraw_state.dart';

final withdrawControllerProvider =
    StateNotifierProvider.autoDispose<WithdrawController, WithdrawState>((ref) {
      return WithdrawController();
    });

class WithdrawController extends StateNotifier<WithdrawState> {
  WithdrawController() : super(WithdrawState.initial());

  final List<String> reasons = const [
    '사용 빈도가 낮아요',
    '원하는 기능이 부족해요',
    '앱 사용이 불편해요',
    '버그나 오류가 많아요',
    '다른 서비스를 이용할 예정이에요',
    '개인정보 및 보안이 걱정돼요',
    '기타',
  ];

  void selectReason(String reason) {
    state = state.copyWith(selectedReason: reason, clearError: true);
  }

  void goNext() {
    if (!state.canGoNext) return;

    state = state.copyWith(step: WithdrawStep.detail, clearError: true);
  }

  void goBack() {
    if (state.step == WithdrawStep.detail) {
      state = state.copyWith(step: WithdrawStep.reason, clearError: true);
    }
  }

  Future<void> submitWithdraw(BuildContext context) async {
    if (state.isLoading) return;

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final selectedReason = state.selectedReason ?? '';
      final detailReason = state.detailController.text.trim();

      await deleteAccount(context);

      state = state.copyWith(isLoading: false);
      SnackbarService.show(
        type: AppSnackType.success,
        message: '회원탈퇴가 완료되었습니다',
      );
    } catch (e) {
      print('에러 : $e');
      SnackbarService.show(
        type: AppSnackType.error,
        message: '탈퇴 처리 중 오류가 발생했어요.',
      );
    }
  }

  Future<void> deleteAccount(BuildContext context) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      // ✅ 1) callable 호출 (배포한 함수명)
      final callable = FirebaseFunctions.instance.httpsCallable(
        'deleteUserData',
      );

      // 필요하면 타임아웃/리트라이를 여기서 관리할 수도 있음
      final res = await callable.call();

      if (kDebugMode) {
        debugPrint('deleteUserData result: ${res.data}');
      }

      // ✅ 2) 함수가 admin.auth().deleteUser(uid)까지 했으면
      // 클라 세션은 남아있을 수 있어서 signOut 처리(안전)
      await FirebaseAuth.instance.signOut();

      state = state.copyWith(isLoading: false);
      Navigator.pop(context);
    } on FirebaseFunctionsException catch (e) {
      // Functions에서 throw한 HttpsError가 여기로 옴
      final msg = e.message ?? '회원탈퇴 실패';
      state = state.copyWith(isLoading: false, errorMessage: msg);
      rethrow;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: '회원탈퇴 실패');
      rethrow;
    }
  }

  @override
  void dispose() {
    state.detailController.dispose();
    super.dispose();
  }
}
