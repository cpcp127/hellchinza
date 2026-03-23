import '../domain/claim_model.dart';

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

  factory ClaimState.initial(ClaimTarget target) {
    return ClaimState(
      isLoading: false,
      errorMessage: null,
      target: target,
      selectedReasons: const [],
      detail: '',
    );
  }

  bool get canSubmit => selectedReasons.isNotEmpty && !isLoading;

  ClaimState copyWith({
    bool? isLoading,
    String? errorMessage,
    List<String>? selectedReasons,
    String? detail,
    bool clearError = false,
  }) {
    return ClaimState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      target: target,
      selectedReasons: selectedReasons ?? this.selectedReasons,
      detail: detail ?? this.detail,
    );
  }
}
