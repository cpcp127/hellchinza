import 'package:flutter/material.dart';

enum WithdrawStep {
  reason,
  detail,
}

class WithdrawState {
  final WithdrawStep step;
  final String? selectedReason;
  final TextEditingController detailController;
  final bool isLoading;
  final String? errorMessage;

  const WithdrawState({
    required this.step,
    required this.selectedReason,
    required this.detailController,
    required this.isLoading,
    this.errorMessage,
  });

  bool get canGoNext => selectedReason != null;
  bool get canWithdraw => !isLoading;

  WithdrawState copyWith({
    WithdrawStep? step,
    String? selectedReason,
    TextEditingController? detailController,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return WithdrawState(
      step: step ?? this.step,
      selectedReason: selectedReason ?? this.selectedReason,
      detailController: detailController ?? this.detailController,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  factory WithdrawState.initial() {
    return WithdrawState(
      step: WithdrawStep.reason,
      selectedReason: null,
      detailController: TextEditingController(),
      isLoading: false,
    );
  }
}