enum AppUpdateStatus {
  checking,
  upToDate,
  optionalUpdate,
  forceUpdate,
  error,
}

class AppUpdateState {
  final bool isLoading;
  final AppUpdateStatus status;
  final String? currentVersion;
  final String? minRequiredVersion;
  final String? latestVersion;
  final String? message;
  final String? storeUrl;
  final String? errorMessage;

  const AppUpdateState({
    required this.isLoading,
    required this.status,
    required this.currentVersion,
    required this.minRequiredVersion,
    required this.latestVersion,
    required this.message,
    required this.storeUrl,
    required this.errorMessage,
  });

  const AppUpdateState.initial()
      : isLoading = true,
        status = AppUpdateStatus.checking,
        currentVersion = null,
        minRequiredVersion = null,
        latestVersion = null,
        message = null,
        storeUrl = null,
        errorMessage = null;

  AppUpdateState copyWith({
    bool? isLoading,
    AppUpdateStatus? status,
    String? currentVersion,
    String? minRequiredVersion,
    String? latestVersion,
    String? message,
    String? storeUrl,
    String? errorMessage,
  }) {
    return AppUpdateState(
      isLoading: isLoading ?? this.isLoading,
      status: status ?? this.status,
      currentVersion: currentVersion ?? this.currentVersion,
      minRequiredVersion: minRequiredVersion ?? this.minRequiredVersion,
      latestVersion: latestVersion ?? this.latestVersion,
      message: message ?? this.message,
      storeUrl: storeUrl ?? this.storeUrl,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}