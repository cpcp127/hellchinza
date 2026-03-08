class SettingState {
  final bool isLoading;
  final String? errorMessage;
  final Map<String, bool> notificationSettings;

  const SettingState({
    this.isLoading = false,
    this.errorMessage,
    this.notificationSettings = const {},
  });

  SettingState copyWith({
    bool? isLoading,
    String? errorMessage,
    Map<String, bool>? notificationSettings,
  }) {
    return SettingState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      notificationSettings: notificationSettings ?? this.notificationSettings,
    );
  }
}
