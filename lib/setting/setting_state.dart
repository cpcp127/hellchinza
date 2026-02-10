class SettingState {
  final bool isLoading;
  final String? errorMessage;

  const SettingState({
    this.isLoading = false,
    this.errorMessage,
  });

  SettingState copyWith({
    bool? isLoading,
    String? errorMessage,
  }) {
    return SettingState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}