import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

// ⚠️ 실제 프로젝트 경로에 맞게 확인해 주세요!
import 'package:hellchinza/feed/data/feed_repo.dart';
import 'package:hellchinza/feed/providers/feed_provider.dart';
import 'package:hellchinza/feed/feed_list/feed_list_controller.dart';
import 'package:hellchinza/feed/domain/feed_model.dart';

class MockFeedRepo extends Mock implements FeedRepo {}
class FakeDocumentSnapshot extends Fake implements DocumentSnapshot<Map<String, dynamic>> {}

void main() {
  late ProviderContainer container;
  late MockFeedRepo mockFeedRepo;

  setUpAll(() {
    registerFallbackValue(FakeDocumentSnapshot());
  });

  setUp(() {
    mockFeedRepo = MockFeedRepo();

    container = ProviderContainer(
      overrides: [
        feedRepoProvider.overrideWithValue(mockFeedRepo),
        // 컨트롤러 내부에서 .future로 가져오는 Provider들을 에러 나지 않게 빈 배열로 오버라이드
        myBlockedUidsProvider.overrideWith((ref) => Stream.value([])),
        myFriendUidsProvider.overrideWith((ref) => Stream.value([])),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  // -----------------------------------------------------------------------------
  // [Test 1] 필터 초기화 및 리프레시 검증
  // 무엇을 테스트하는가? 사용자가 필터를 변경했을 때, 상태가 정확히 업데이트되고
  // 데이터를 처음부터 다시 불러오는지(resetAndFetch) 검증합니다.
  // -----------------------------------------------------------------------------
  test('applyFilters 호출 시 필터 상태가 갱신되고, 데이터가 초기화된 후 다시 로드되어야 한다', () async {
    // 🔥 [핵심 해결책] autoDispose 프로바이더가 테스트 도중 죽지 않게 생명줄을 잡아줍니다.
    final subscription = container.listen(feedListControllerProvider, (_, __) {});

    final controller = container.read(feedListControllerProvider.notifier);

    when(() => mockFeedRepo.fetchFeedPage(
      mainType: any(named: 'mainType'),
      subType: any(named: 'subType'),
      onlyFriendFeeds: any(named: 'onlyFriendFeeds'),
      blockedUids: any(named: 'blockedUids'),
      friendUids: any(named: 'friendUids'),
      pageSize: any(named: 'pageSize'),
    )).thenAnswer((_) async => const FeedPageResult(items: [], lastDoc: null, hasMore: false));

    controller.applyFilters(mainType: '질문', subType: '전체', onlyFriends: true);

    // 비동기 처리 대기 중에도 listen 하고 있으므로 상태가 날아가지 않습니다!
    await Future.delayed(Duration.zero);

    final state = container.read(feedListControllerProvider);
    expect(state.selectMainType, '질문');
    expect(state.onlyFriendFeeds, true);
    expect(state.refreshTick, 1);

    subscription.close(); // 테스트 끝난 후 생명줄 해제
  });

  // -----------------------------------------------------------------------------
  // [Test 2] 무한 스크롤 방어 로직 검증
  // -----------------------------------------------------------------------------
  test('이미 다음 페이지를 로딩 중일 때 fetchNextPage를 호출하면 무시되어야 한다', () async {
    container = ProviderContainer(
      overrides: [
        feedRepoProvider.overrideWithValue(mockFeedRepo),
        feedListControllerProvider.overrideWith((ref) {
          final ctrl = FeedListController(ref);
          ctrl.state = ctrl.state.copyWith(
              isLoadingMore: true,
              hasMore: true,
              lastDoc: FakeDocumentSnapshot()
          );
          return ctrl;
        }),
      ],
    );

    // 🔥 여기서도 생명줄 묶어주기!
    final subscription = container.listen(feedListControllerProvider, (_, __) {});

    final controller = container.read(feedListControllerProvider.notifier);

    await controller.fetchNextPage();

    verifyNever(() => mockFeedRepo.fetchFeedPage(
      mainType: any(named: 'mainType'),
      subType: any(named: 'subType'),
      onlyFriendFeeds: any(named: 'onlyFriendFeeds'),
      blockedUids: any(named: 'blockedUids'),
      friendUids: any(named: 'friendUids'),
      pageSize: any(named: 'pageSize'),
      startAfter: any(named: 'startAfter'),
    ));

    subscription.close();
  });

  // -----------------------------------------------------------------------------
  // [Test 2] 무한 스크롤 방어 로직 검증 (포트폴리오 핵심 포인트!)
  // 무엇을 테스트하는가? 데이터를 불러오는 중(isLoadingMore == true)일 때
  // 스크롤을 또 내려서 fetchNextPage()가 중복 호출되는 것을 완벽히 방어하는지 테스트합니다.
  // -----------------------------------------------------------------------------
  test('이미 다음 페이지를 로딩 중일 때 fetchNextPage를 호출하면 무시되어야 한다', () async {
    // 1. 강제로 로딩 중인 상태 생성
    container = ProviderContainer(
      overrides: [
        feedRepoProvider.overrideWithValue(mockFeedRepo),
        feedListControllerProvider.overrideWith((ref) {
          final ctrl = FeedListController(ref);
          // 임의로 isLoadingMore를 true로, lastDoc을 세팅해둡니다.
          ctrl.state = ctrl.state.copyWith(
              isLoadingMore: true,
              hasMore: true,
              lastDoc: FakeDocumentSnapshot()
          );
          return ctrl;
        }),
      ],
    );

    final controller = container.read(feedListControllerProvider.notifier);

    // 2. 실행: 중복 로드 시도
    await controller.fetchNextPage();

    // 3. 검증: Repo의 fetchFeedPage가 단 1번도 호출되지 않아야 함 (방어 성공!)
    verifyNever(() => mockFeedRepo.fetchFeedPage(
      mainType: any(named: 'mainType'),
      subType: any(named: 'subType'),
      onlyFriendFeeds: any(named: 'onlyFriendFeeds'),
      blockedUids: any(named: 'blockedUids'),
      friendUids: any(named: 'friendUids'),
      pageSize: any(named: 'pageSize'),
      startAfter: any(named: 'startAfter'),
    ));
  });
}