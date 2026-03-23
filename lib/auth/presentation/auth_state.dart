class AuthState {
  final bool isLoading;
  final String nickname;
  final String? errorMessage;

  const AuthState({
    this.isLoading = false,
    this.nickname = '',
    this.errorMessage,
  });

  AuthState copyWith({
    bool? isLoading,
    String? nickname,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      nickname: nickname ?? this.nickname,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}