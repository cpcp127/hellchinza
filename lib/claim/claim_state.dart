import 'domain/claim_model.dart';

class ClaimState {
  final bool isLoading;
  final String? errorMessage;

  final ClaimTarget target;

  final List<String> selectedReasons;
  final String detail;

  const ClaimState({
    required this.isLoading,
    required this.errorMessage,
    required this.target,
    required this.selectedReasons,
    required this.detail,
  });

  factory ClaimState.initial(ClaimTarget target) => ClaimState(
    isLoading: false,
    errorMessage: null,
    target: target,
    selectedReasons: const [],
    detail: '',
  );

  bool get canSubmit => selectedReasons.isNotEmpty && !isLoading;

  ClaimState copyWith({
    bool? isLoading,
    String? errorMessage,
    List<String>? selectedReasons,
    String? detail,
  }) {
    return ClaimState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      target: target,
      selectedReasons: selectedReasons ?? this.selectedReasons,
      detail: detail ?? this.detail,
    );
  }
}
