class ProfileState {
  final bool isLoading;

  ProfileState({this.isLoading = false});

  ProfileState copyWith({bool? isLoading}) {
    return ProfileState(isLoading: isLoading ?? this.isLoading);
  }
}
