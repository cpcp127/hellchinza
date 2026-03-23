class HomeState {
  final int navIndex;
  final int pageIndex;

  const HomeState({this.navIndex = 0, this.pageIndex = 0});

  HomeState copyWith({int? navIndex, int? pageIndex}) {
    return HomeState(
      navIndex: navIndex ?? this.navIndex,
      pageIndex: pageIndex ?? this.pageIndex,
    );
  }
}
