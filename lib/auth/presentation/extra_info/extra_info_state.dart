class ExtraInfoState {
  final bool isLoading;
  final String? nicknameErrorText;
  final int currentIndex;
  final String nickname;
  final String? gender;
  final List<String> selectedCategory;
  final String? errorMessage;

  const ExtraInfoState({
    this.isLoading = false,
    this.nicknameErrorText,
    this.gender,
    this.nickname = '',
    this.currentIndex = 0,
    this.selectedCategory = const [],
    this.errorMessage,
  });

  ExtraInfoState copyWith({
    bool? isLoading,
    String? nicknameErrorText,
    String? nickname,
    String? gender,
    int? currentIndex,
    List<String>? selectedCategory,
    String? errorMessage,
    bool clearNicknameError = false,
    bool clearError = false,
  }) {
    return ExtraInfoState(
      isLoading: isLoading ?? this.isLoading,
      nicknameErrorText: clearNicknameError
          ? null
          : (nicknameErrorText ?? this.nicknameErrorText),
      currentIndex: currentIndex ?? this.currentIndex,
      nickname: nickname ?? this.nickname,
      gender: gender ?? this.gender,
      selectedCategory: selectedCategory ?? this.selectedCategory,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}
