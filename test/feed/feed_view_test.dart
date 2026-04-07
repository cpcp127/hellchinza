import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'dart:async'; // 🔥 Completer를 사용하기 위해 맨 위에 추가해 주세요.
// ⚠️ 실제 경로 확인 필수!
import 'package:hellchinza/feed/feed_list/feed_list_view.dart';
import 'package:hellchinza/feed/feed_detail/feed_detail_view.dart';

import 'package:hellchinza/feed/feed_list/feed_list_controller.dart';
import 'package:hellchinza/feed/providers/feed_provider.dart';
import 'package:hellchinza/feed/domain/feed_model.dart';
import 'package:flutter/cupertino.dart';

void main() {
  // -----------------------------------------------------------------------------
  // [Test 1] FeedListView - 데이터 없음(Empty) 상태 검증
  // 무엇을 테스트하는가? 서버에서 받아온 피드가 0개일 때, 하얀 빈 화면이 아니라
  // 사용자를 유도하는 "아직 피드가 없어요" 화면(EmptyList 위젯)이 잘 노출되는가?
  // -----------------------------------------------------------------------------
  testWidgets('FeedListView 로딩 완료 후 데이터가 없으면 EmptyList가 노출되어야 한다', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          // 차단/친구 데이터는 로딩 완료 상태로 모방
          myBlockedUidsProvider.overrideWith((ref) => Stream.value([])),
          myFriendUidsProvider.overrideWith((ref) => Stream.value([])),
          // 컨트롤러의 상태를 강제로 "로딩 완료, 아이템 0개"로 주입
          feedListControllerProvider.overrideWith((ref) {
            final ctrl = FeedListController(ref);
            ctrl.state = ctrl.state.copyWith(isLoading: false, items: []);
            return ctrl;
          }),
        ],
        child: const MaterialApp(home: Scaffold(body: FeedListView())),
      ),
    );

    // UI가 모두 그려질 때까지 대기
    await tester.pumpAndSettle();

    // 검증: "아직 피드가 없어요" 텍스트가 화면에 딱 1개 존재하는지 확인
    expect(find.text('아직 피드가 없어요'), findsOneWidget);
    // 피드 카드는 하나도 없어야 함
    expect(find.text('피드'), findsNothing);
  });

  // -----------------------------------------------------------------------------
  // [Test 2] FeedDetailView - 로딩 상태 검증
  // 무엇을 테스트하는가? Riverpod의 FutureProvider(feedDocProvider)가 데이터를
  // 가져오는 동안 화면에 로딩 스피너(CupertinoActivityIndicator)가 돌아가는지 확인
  // -----------------------------------------------------------------------------
  testWidgets('FeedDetailView 진입 시 데이터를 불러오는 동안 로딩 인디케이터가 표시되어야 한다', (WidgetTester tester) async {
    // 1. 타이머 대신 '결과를 나중에 알려줄게'라는 Completer 객체를 만듭니다.
    final completer = Completer<FeedModel?>();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          feedDocProvider.overrideWith((ref, id) {
            // Future.delayed 대신, 완료되지 않은 Future 자체를 던져줍니다.
            // 이렇게 하면 타이머 에러 없이 완벽한 '로딩 중' 상태가 만들어집니다.
            return completer.future;
          }),
        ],
        child: const MaterialApp(home: FeedDetailView(feedId: 'test_feed_123')),
      ),
    );

    // 펌프 1번: 애니메이션의 첫 프레임만 렌더링
    await tester.pump();

    // 검증: 화면에 CupertinoActivityIndicator 위젯이 존재하는가?
    expect(find.byType(CupertinoActivityIndicator), findsOneWidget);

    // 🔥 플러터 테스트 환경이 안심하고 종료할 수 있도록, 테스트 맨 마지막에 작업을 완료시켜 줍니다.
    completer.complete(null);
  });

  // -----------------------------------------------------------------------------
  // [Test 3] FeedDetailView - 삭제된 피드 방어 로직 검증
  // 무엇을 테스트하는가? 누군가 링크를 타고 들어왔거나, 이미 삭제된 피드를 요청했을 때
  // 에러를 뿜으며 뻗지 않고 "피드가 없어요"라고 유저 친화적으로 알려주는지 검증
  // -----------------------------------------------------------------------------
  testWidgets('FeedDetailView에서 피드 데이터가 null이면 "피드가 없어요" 텍스트를 노출해야 한다', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          // DB에 데이터가 없어서 null을 반환한 상황을 모방
          feedDocProvider.overrideWith((ref, id) async => null),
        ],
        child: const MaterialApp(home: FeedDetailView(feedId: 'deleted_feed')),
      ),
    );

    // 비동기 데이터 렌더링을 끝까지 기다림
    await tester.pumpAndSettle();

    // 검증: 에러 텍스트가 노출되는가?
    expect(find.text('피드가 없어요'), findsOneWidget);
  });
}