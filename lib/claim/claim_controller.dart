import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'claim_state.dart';
import 'claim_service.dart';
import 'domain/claim_model.dart';

// 서비스 provider
final claimServiceProvider = Provider<ClaimService>((ref) {
  return ClaimService(FirebaseFirestore.instance);
});

// 화면용 controller provider (target을 인자로 받음)
final claimControllerProvider =
StateNotifierProvider.autoDispose.family<ClaimController, ClaimState, ClaimTarget>(
      (ref, target) => ClaimController(ref, target),
);

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
    state = state.copyWith(selectedReasons: list, errorMessage: null);
  }

  void setDetail(String v) {
    state = state.copyWith(detail: v, errorMessage: null);
  }

  Future<void> submit({
    required String reporterUid,
  }) async {
    if (!state.canSubmit) return;

    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      await ref.read(claimServiceProvider).createClaim(
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
