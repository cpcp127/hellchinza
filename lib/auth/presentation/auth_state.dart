class AuthState {
  final bool isLoading;
  final String? nickname;

  AuthState({this.isLoading = false, this.nickname});

  AuthState copyWith({bool? isLoading, String? nickname}) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      nickname: nickname ?? this.nickname,
    );
  }
}
