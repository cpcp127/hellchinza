import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:image_picker/image_picker.dart';

// ⚠️ 실제 프로젝트 경로에 맞게 확인해 주세요! (빨간 줄이 뜨면 Alt+Enter로 경로 수정)
import 'package:hellchinza/feed/data/feed_repo.dart';
import 'package:hellchinza/feed/providers/feed_provider.dart';
import 'package:hellchinza/feed/create_feed/create_feed_controller.dart';
import 'package:hellchinza/feed/domain/feed_place.dart';
import 'package:hellchinza/feed/domain/feed_model.dart'; // FeedModel import 추가

class FakeXFile extends Fake implements XFile {}

class FakeFeedPlace extends Fake implements FeedPlace {}

class MockFeedRepo extends Mock implements FeedRepo {}

void main() {
  late ProviderContainer container;
  late MockFeedRepo mockFeedRepo;

  setUpAll(() {
    registerFallbackValue(FakeXFile());
    registerFallbackValue(FakeFeedPlace());
    registerFallbackValue((double v) {});
  });

  setUp(() {
    mockFeedRepo = MockFeedRepo();
    container = ProviderContainer(
      overrides: [feedRepoProvider.overrideWithValue(mockFeedRepo)],
    );
  });

  tearDown(() {
    container.dispose();
  });

  // -----------------------------------------------------------------------------
  // [Test 2] 투표 옵션 개수 제한 테스트
  // -----------------------------------------------------------------------------
  test('투표 옵션 추가 시, 최대 6개까지만 추가되어야 한다', () {
    final controller = container.read(createFeedControllerProvider.notifier);
    controller.ensurePollDefaults();
    for (int i = 0; i < 5; i++) {
      controller.addPollOption();
    }

    final state = container.read(createFeedControllerProvider);
    expect(state.pollOptions.length, 6); // 7번 시도해도 6개로 고정됨
  });

  // -----------------------------------------------------------------------------
  // 🔥 [Test 3] 수정 모드(initForEdit) 데이터 매핑 테스트 [신규 추가]
  // 무엇을 테스트하는가? 기존 피드를 수정하려고 열었을 때, 기존 데이터가 State에 잘 복사되는지 확인
  // -----------------------------------------------------------------------------
  test('initForEdit 호출 시, 피드의 기존 정보가 State에 올바르게 세팅되어야 한다', () {
    final controller = container.read(createFeedControllerProvider.notifier);

    // 임의의 기존 피드 데이터 생성
    final dummyFeed = FeedModel(
      id: 'feed_123',
      authorUid: 'user_1',
      mainType: '오운완',
      contents: '오늘 운동 완료!',
      imageUrls: ['https://img1.com', 'https://img2.com'],
      commentCount: 0,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    // 실행
    controller.initForEdit(dummyFeed);

    // 검증
    final state = container.read(createFeedControllerProvider);
    expect(state.pageIndex, 2);
    expect(state.selectMainType, '오운완');
    expect(state.contents, '오늘 운동 완료!');
    expect(state.existingImageUrls.length, 2);
    expect(state.newImageFiles.isEmpty, true);
  });

  // -----------------------------------------------------------------------------
  // 🔥 [Test 4] 이미지 삭제 분기(removeImageAt) 로직 테스트 [신규 추가]
  // 무엇을 테스트하는가? 기존에 있던 이미지를 지우면 removedImageUrls로 이동하고,
  // 새로 추가하려던 이미지를 지우면 그냥 사라지는 복잡한 인덱스 계산 로직 검증
  // -----------------------------------------------------------------------------
  test('removeImageAt 호출 시, 기존 이미지면 removed 배열로 가고, 새 이미지면 상태에서만 삭제되어야 한다', () {
    final controller = container.read(createFeedControllerProvider.notifier);

    // 1. 기존 이미지 2개가 있는 피드로 초기화
    final dummyFeed = FeedModel(
      id: 'feed_123',
      authorUid: 'user_1',
      mainType: '오운완',
      commentCount: 0,
      imageUrls: ['url_A', 'url_B'],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    controller.initForEdit(dummyFeed);

    // 2. 인덱스 0번(기존 이미지 url_A) 삭제 실행
    controller.removeImageAt(0);

    // 3. 검증
    final state = container.read(createFeedControllerProvider);
    expect(state.existingImageUrls, ['url_B']); // B만 남아야 함
    expect(state.removedImageUrls, ['url_A']); // A는 삭제 대기열로 이동해야 함
  });

  // -----------------------------------------------------------------------------
  // [Test 5] 업로드 성공 테스트 (기존 유지)
  // -----------------------------------------------------------------------------
  testWidgets('피드 업로드(submitFeed) 시, Repo의 createFeed가 정상적으로 호출되어야 한다', (
    WidgetTester tester,
  ) async {
    final controller = container.read(createFeedControllerProvider.notifier);

    late BuildContext realContext;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            realContext = context;
            return const Scaffold();
          },
        ),
      ),
    );

    when(
      () => mockFeedRepo.createFeed(
        mainType: any(named: 'mainType'),
        subType: any(named: 'subType'),
        contents: any(named: 'contents'),
        newImageFiles: any(named: 'newImageFiles'),
        pollOptions: any(named: 'pollOptions'),
        selectedPlace: any(named: 'selectedPlace'),
        visibility: any(named: 'visibility'),
        meetId: any(named: 'meetId'),
        onProgress: any(named: 'onProgress'),
      ),
    ).thenAnswer((_) async => Future.value());

    controller.onChangeMainType('질문');
    controller.onChangeText('정상 작동 테스트');

    await tester.runAsync(() async {
      try {
        await controller.submitFeed(realContext, null);
      } catch (_) {}
    });
    await tester.pumpAndSettle();

    verify(
      () => mockFeedRepo.createFeed(
        mainType: any(named: 'mainType'),
        subType: any(named: 'subType'),
        contents: any(named: 'contents'),
        newImageFiles: any(named: 'newImageFiles'),
        pollOptions: any(named: 'pollOptions'),
        selectedPlace: any(named: 'selectedPlace'),
        visibility: any(named: 'visibility'),
        meetId: any(named: 'meetId'),
        onProgress: any(named: 'onProgress'),
      ),
    ).called(1);
  });

  // -----------------------------------------------------------------------------
  // 🔥 [Test 6] 업로드 실패(Exception) 방어 테스트 [신규 추가]
  // 무엇을 테스트하는가? 네트워크 오류 등으로 Repo에서 에러를 던졌을 때,
  // 앱이 튕기지(Crash) 않고 안전하게 예외 처리를 완료하는지 검증 (포트폴리오 핵심 역량)
  // -----------------------------------------------------------------------------
  testWidgets('피드 업로드 중 네트워크 에러 발생 시, 앱이 죽지 않고 예외를 처리해야 한다', (
    WidgetTester tester,
  ) async {
    final controller = container.read(createFeedControllerProvider.notifier);

    late BuildContext realContext;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            realContext = context;
            return const Scaffold();
          },
        ),
      ),
    );

    // Repo가 강제로 Exception을 던지도록(throw) 악의적으로 설정
    when(
      () => mockFeedRepo.createFeed(
        mainType: any(named: 'mainType'),
        subType: any(named: 'subType'),
        contents: any(named: 'contents'),
        newImageFiles: any(named: 'newImageFiles'),
        pollOptions: any(named: 'pollOptions'),
        selectedPlace: any(named: 'selectedPlace'),
        visibility: any(named: 'visibility'),
        meetId: any(named: 'meetId'),
        onProgress: any(named: 'onProgress'),
      ),
    ).thenThrow(Exception('Firebase Network Error!'));

    // 실행: Exception이 던져지지만, 컨트롤러 내부의 try-catch가 이를 방어해야 함
    await tester.runAsync(() async {
      try {
        // 내부 try-catch가 정상 작동하면 여기서 에러가 밖으로 새어나오지 않습니다.
        await controller.submitFeed(realContext, null);
      } catch (e) {
        fail('컨트롤러가 에러를 뱉어내면 안 됩니다. 내부 catch 블록에서 처리되어야 합니다.');
      }
    });

    await tester.pumpAndSettle();

    // 에러 상황에서도 Repo 호출 자체는 시도되었음을 검증
    verify(
      () => mockFeedRepo.createFeed(
        mainType: any(named: 'mainType'),
        subType: any(named: 'subType'),
        contents: any(named: 'contents'),
        newImageFiles: any(named: 'newImageFiles'),
        pollOptions: any(named: 'pollOptions'),
        selectedPlace: any(named: 'selectedPlace'),
        visibility: any(named: 'visibility'),
        meetId: any(named: 'meetId'),
        onProgress: any(named: 'onProgress'),
      ),
    ).called(1);
  });
}
