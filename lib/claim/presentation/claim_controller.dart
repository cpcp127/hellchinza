import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../auth/providers/auth_provider.dart';
import '../providers/claim_provider.dart';
import 'claim_state.dart';
import '../domain/claim_model.dart';

class ClaimController extends StateNotifier<ClaimState> {
  ClaimController(this.ref, ClaimTarget target)
    : super(ClaimState.initial(target));

  final Ref ref;

  static const List<String> reasonPool = [
    '스팸/도배',
    '욕설/비방',
    '혐오/차별',
    '음란/선정',
    '사기/홍보',
    '개인정보 노출',
    '기타',
  ];

  void toggleReason(String reason) {
    final list = [...state.selectedReasons];

    if (list.contains(reason)) {
      list.remove(reason);
    } else {
      list.add(reason);
    }

    state = state.copyWith(selectedReasons: list, clearError: true);
  }

  void setDetail(String value) {
    state = state.copyWith(detail: value, clearError: true);
  }

  Future<void> submit() async {
    if (!state.canSubmit) return;

    final reporterUid = ref.read(firebaseAuthProvider).currentUser?.uid;
    if (reporterUid == null || reporterUid.isEmpty) {
      state = state.copyWith(errorMessage: '로그인이 필요합니다.');
      throw Exception('로그인이 필요합니다.');
    }

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      await ref
          .read(claimRepoProvider)
          .createClaim(
            reporterUid: reporterUid,
            target: state.target,
            reasons: state.selectedReasons,
            detail: state.detail,
          );

      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: '신고에 실패했어요. 잠시 후 다시 시도해주세요.',
      );
      rethrow;
    }
  }
}
