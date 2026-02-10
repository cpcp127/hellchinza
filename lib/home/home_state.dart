
class HomeState {
  final int pageIndex;

  HomeState({this.pageIndex = 0});

  HomeState copyWith({int? pageIndex}) {
    return HomeState(pageIndex: pageIndex ?? this.pageIndex);
  }
}