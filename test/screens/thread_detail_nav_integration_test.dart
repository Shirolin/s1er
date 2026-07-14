import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:s1_app/models/user.dart';
import 'package:s1_app/models/open_scroll_target.dart';
import 'package:s1_app/providers/auth_provider.dart';
import 'package:s1_app/providers/post_provider.dart';
import 'package:s1_app/providers/reading_history_provider.dart';
import 'package:s1_app/providers/settings_provider.dart';
import 'package:s1_app/providers/thread_open_intent_provider.dart';
import 'package:s1_app/screens/thread_detail_screen.dart';
import 'package:s1_app/services/http_client.dart';
import 'package:s1_app/services/reading_history_service.dart';
import 'package:s1_app/theme/app_theme.dart';
import 'package:s1_app/utils/thread_navigation.dart';
import 'package:s1_app/widgets/pagination_bar.dart';

import '../helpers/test_local_data.dart';

Future<void> _pumpFrames(WidgetTester tester, int frames) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// Integration coverage for thread open contract + URL sync + floor resume.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _ViewthreadAdapter adapter;
  late ProviderContainer? rootContainer;

  setUp(() {
    adapter = _ViewthreadAdapter();
    rootContainer = null;
  });

  tearDown(() {
    rootContainer?.dispose();
  });

  Future<GoRouter> pumpThread({
    required WidgetTester tester,
    required String location,
    void Function(ReadingHistoryService service)? seedHistory,
    bool useNestedIntentOverride = false,
  }) async {
    final (db, local) = await openTestLocalData();
    addTearDown(db.close);
    await local.ensureReadingHistoryLoaded();
    await local.ensureBlacklistLoaded();
    await local.ensurePollVotesLoaded();

    final dio = Dio()..httpClientAdapter = adapter;
    final uri = Uri.parse(location);
    final tid = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : '100';
    final intent = ThreadRouteCodec.intentFromUri(uri, tid: tid);
    late ProviderContainer container;
    container = ProviderContainer(
      overrides: [
        localDataProvider.overrideWithValue(local),
        httpClientProvider.overrideWith(
          (ref) => S1HttpClient.test(container, dio),
        ),
        settingsProvider.overrideWith(
          () => SettingsNotifier(
            initial: const AppSettings(
              showImages: false,
              recordReadingHistory: true,
            ),
          ),
        ),
        authStateProvider.overrideWith(_GuestAuthNotifier.new),
        if (!useNestedIntentOverride)
          threadOpenIntentProvider(tid).overrideWithValue(intent),
      ],
    );
    rootContainer = container;
    seedHistory?.call(container.read(readingHistoryServiceProvider));
    // Rebuild readingHistoryProvider after seed.
    container.read(readingHistoryProvider.notifier).refresh();

    final router = GoRouter(
      initialLocation: location,
      routes: [
        GoRoute(
          path: '/thread/:tid',
          pageBuilder: (context, state) {
            final routeTid = state.pathParameters['tid']!;
            final screen = ThreadDetailScreen(tid: routeTid);
            return NoTransitionPage<void>(
              key: ValueKey('thread-$routeTid'),
              child: useNestedIntentOverride
                  ? ProviderScope(
                      overrides: [
                        threadOpenIntentProvider(routeTid)
                            .overrideWithValue(intent),
                      ],
                      child: screen,
                    )
                  : screen,
            );
          },
        ),
      ],
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          theme: AppTheme.lightTheme('purple'),
          routerConfig: router,
        ),
      ),
    );

    // Allow open-scroll consume + rate-log side effects to settle.
    for (var i = 0; i < 80; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      if (find.byType(PaginationBar).evaluate().isNotEmpty ||
          find.textContaining('MARK-FLOOR-').evaluate().isNotEmpty) {
        // Extra frames for open-scroll animations.
        await _pumpFrames(tester, 20);
        break;
      }
    }
    return router;
  }

  testWidgets('in-thread next page replaces URL with ?page=', (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);

    final router = await pumpThread(
      tester: tester,
      location: '/thread/100?page=1',
    );

    expect(find.text('第 1 / 3 页'), findsOneWidget);
    expect(router.state.uri.toString(), '/thread/100?page=1');

    await tester.tap(find.byIcon(Icons.chevron_right));
    await _pumpFrames(tester, 40);

    expect(find.text('第 2 / 3 页'), findsOneWidget);
    expect(router.state.uri.queryParameters['page'], '2');
    expect(router.state.uri.queryParameters.containsKey('pid'), isFalse);
  });

  testWidgets('route-scoped page intent opens the selected list page',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);

    await pumpThread(
      tester: tester,
      location: '/thread/100?page=2',
      useNestedIntentOverride: true,
    );

    expect(adapter.requestedPages.first, 2);
    expect(find.text('第 2 / 3 页'), findsOneWidget);
  });

  testWidgets('resume opens mid-floor and writeback updates lastReadFloor',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);

    adapter.postsPerPage = 8;
    adapter.totalReplies = 20;

    await pumpThread(
      tester: tester,
      location: '/thread/100',
      seedHistory: (service) {
        service.updateProgress(
          tid: '100',
          page: 1,
          floorInPage: 5,
          subject: 'Nav Integration',
          author: 'author',
          fid: '4',
          totalPages: 3,
          totalReplies: 20,
          perPage: 8,
          isNewVisit: true,
        );
      },
    );

    // Absolute floor 5 should be scrolled into view after resume.
    expect(find.textContaining('MARK-FLOOR-5'), findsOneWidget);

    final before =
        rootContainer!.read(readingHistoryServiceProvider).getRecord('100')!;
    // After resume consume, visible-floor writeback should keep mid-floor
    // (not the old page-end fake progress).
    expect(before.lastReadFloor, inInclusiveRange(4, 6));

    // Drive the detail ListView controller so scroll metrics fire.
    final listFinder = find.descendant(
      of: find.byType(ThreadDetailScreen),
      matching: find.byType(ListView),
    );
    final listView = tester.widget<ListView>(listFinder);
    final controller = listView.controller!;
    expect(controller.position.maxScrollExtent, greaterThan(500));

    // Throttle uses wall-clock DateTime.now(); advance real time via runAsync.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 450)),
    );

    controller.jumpTo(controller.position.maxScrollExtent);
    await _pumpFrames(tester, 15);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 450)),
    );
    // Nudge once more after lazy children build (extent may grow).
    controller.jumpTo(controller.position.maxScrollExtent);
    await _pumpFrames(tester, 15);

    final after =
        rootContainer!.read(readingHistoryServiceProvider).getRecord('100')!;
    expect(after.lastReadFloor, greaterThan(before.lastReadFloor));
    expect(after.lastReadPage, 1);
  });

  testWidgets('forced page=1 ignores resume floor and stays at page top',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);

    adapter.postsPerPage = 8;
    adapter.totalReplies = 40;

    await pumpThread(
      tester: tester,
      location: '/thread/100?page=1',
      seedHistory: (service) {
        service.updateProgress(
          tid: '100',
          page: 2,
          floorInPage: 4,
          subject: 'Nav Integration',
          author: 'author',
          fid: '4',
          totalPages: 6,
          totalReplies: 40,
          perPage: 8,
          isNewVisit: true,
        );
      },
    );

    final state = rootContainer!.read(postProvider('100')).asData?.value;
    expect(state, isNotNull);
    expect(state!.currentPage, 1);
    expect(adapter.requestedPages.first, 1);
    // Force-page lands at page top (ScrollToPageTop already consumed).
    expect(state.openScrollTarget, isNull);
    expect(find.textContaining('MARK-FLOOR-1'), findsOneWidget);
    expect(find.textContaining('MARK-FLOOR-12'), findsNothing);
  });

  testWidgets('pid open highlights target and ignores resume floor',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);

    adapter.postsPerPage = 8;
    adapter.totalReplies = 20;
    adapter.locatePageForPid['pid-6'] = 1;

    await pumpThread(
      tester: tester,
      location: '/thread/100?pid=pid-6',
      seedHistory: (service) {
        service.updateProgress(
          tid: '100',
          page: 1,
          floorInPage: 2,
          subject: 'Nav Integration',
          author: 'author',
          fid: '4',
          totalPages: 3,
          totalReplies: 20,
          perPage: 8,
          isNewVisit: true,
        );
      },
    );

    final state = rootContainer!.read(postProvider('100')).asData?.value;
    expect(state, isNotNull);
    expect(state!.currentPage, 1);
    expect(state.posts.any((p) => p.pid == 'pid-6'), isTrue);
    expect(state.locateError, isNull);
    // Resume floor must not override pid intent.
    expect(state.openScrollTarget, anyOf(isNull, isA<ScrollToPid>()));
    expect(find.textContaining('MARK-FLOOR-6'), findsOneWidget);
  });
}

class _GuestAuthNotifier extends AuthNotifier {
  @override
  AuthState build() {
    return AuthState(
      isLoggedIn: false,
      username: null,
      user: User(uid: '', username: ''),
    );
  }
}

class _ViewthreadAdapter implements HttpClientAdapter {
  int postsPerPage = 3;
  int totalReplies = 8;
  final requestedPages = <int>[];
  final locatePageForPid = <String, int>{};

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final uri = options.uri;

    if (uri.queryParameters['goto'] == 'findpost') {
      final pid = uri.queryParameters['pid'] ?? '';
      final ptid = uri.queryParameters['ptid'] ?? '';
      final page = locatePageForPid[pid] ?? 1;
      return ResponseBody.fromString(
        '',
        302,
        headers: {
          'location': [
            'https://stage1st.com/2b/forum.php?mod=viewthread&tid=$ptid&page=$page',
          ],
        },
      );
    }

    if (uri.query.contains('module=viewthread')) {
      final page = int.tryParse(uri.queryParameters['page'] ?? '1') ?? 1;
      requestedPages.add(page);
      final posts = <Map<String, dynamic>>[];
      for (var i = 0; i < postsPerPage; i++) {
        final absoluteFloor = (page - 1) * postsPerPage + i + 1;
        // Tall plain-text posts (avoid heavy HTML) so floor scroll/writeback work.
        final spacer = List.filled(30, 'line$absoluteFloor').join('\n');
        posts.add({
          'pid': 'pid-$absoluteFloor',
          'author': 'author$absoluteFloor',
          'authorid': '$absoluteFloor',
          'message': 'MARK-FLOOR-$absoluteFloor\n$spacer',
          'dateline': '1700000000',
          'dbdateline': '1700000000',
          'number': '$absoluteFloor',
        });
      }

      return ResponseBody.fromString(
        jsonEncode({
          'Variables': {
            'ppp': '$postsPerPage',
            'thread': {
              'subject': 'Nav Integration',
              'fid': '4',
              'replies': '$totalReplies',
              'allowreply': '1',
            },
            'postlist': posts,
          },
        }),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }

    if (uri.query.contains('mod=viewthread')) {
      return ResponseBody.fromString('<html></html>', 200);
    }

    return ResponseBody.fromString('{}', 200);
  }
}
