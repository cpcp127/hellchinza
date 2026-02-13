class ExtraInfoState {
  final bool isLoading;
  final String? nicknameErrorText;
  final int currentIndex;
  final String? nickname;
  final String? gender;
  final List<String>? selectedCategory;

  ExtraInfoState({
    this.isLoading = false,
    this.nicknameErrorText,
    this.gender,
    this.nickname,
    this.currentIndex = 0,
    this.selectedCategory,
  });

  ExtraInfoState copyWith({
    bool? isLoading,
    String? nicknameErrorText,
    String? nickname,
    String? gender,
    int? currentIndex,
    List<String>? selectedCategory,
  }) {
    return ExtraInfoState(
      isLoading: isLoading ?? this.isLoading,
      nicknameErrorText: nicknameErrorText ?? this.nicknameErrorText,
      currentIndex: currentIndex ?? this.currentIndex,
      nickname: nickname ?? this.nickname,
      gender:  gender ?? this.gender,
      selectedCategory: selectedCategory ?? this.selectedCategory,
    );
  }
}
