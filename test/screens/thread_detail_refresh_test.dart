import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:s1er/models/post.dart';
import 'package:s1er/providers/post_provider.dart';
import 'package:s1er/providers/settings_provider.dart';
import 'package:s1er/providers/thread_rate_logs_provider.dart';
import 'package:s1er/screens/thread_detail_screen.dart';
import 'package:s1er/theme/app_theme.dart';
import 'package:s1er/widgets/app_bar_more_menu.dart';
import 'package:s1er/widgets/s1_swipe_pagination.dart';
import 'package:s1er/models/rate_log.dart';

import '../helpers/test_local_data.dart';

class _TestThreadRateLogsNotifier extends ThreadRateLogsNotifier {
  _TestThreadRateLogsNotifier(super.tid);

  @override
  Map<String, PostRateLog> build() => const {};
}

class _FakePostNotifier extends PostNotifier {
  _FakePostNotifier(
    super.tid, {
    this.empty = false,
    this.lastPageIncomplete = false,
  });

  final bool empty;
  final bool lastPageIncomplete;
  int refreshCount = 0;

  @override
  Future<PostListState> build() async {
    if (empty) {
      return PostListState(
        posts: const [],
        currentPage: 1,
        totalPages: 1,
        perPage: 10,
        totalReplies: 0,
        threadSubject: '空帖',
      );
    }
    if (lastPageIncomplete) {
      return PostListState(
        posts: [
          Post(
            pid: '21',
            author: '用户',
            authorId: '1',
            message: '末页楼',
            dateline: 1700000000,
            floor: 21,
          ),
          Post(
            pid: '22',
            author: '用户',
            authorId: '1',
            message: '最后一贴',
            dateline: 1700000001,
            floor: 22,
          ),
        ],
        currentPage: 3,
        totalPages: 3,
        perPage: 10,
        totalReplies: 22,
        threadSubject: '末页主题',
      );
    }
    return PostListState(
      posts: [
        Post(
          pid: '1',
          author: '用户',
          authorId: '1',
          message: '楼层正文',
          dateline: 1700000000,
          floor: 1,
        ),
      ],
      currentPage: 1,
      totalPages: 2,
      perPage: 10,
      totalReplies: 11,
      threadSubject: '测试主题',
    );
  }

  @override
  Future<void> refresh() async {
    refreshCount++;
  }
}

Future<void> _pumpThread({
  required WidgetTester tester,
  required String tid,
  required PostNotifier notifier,
}) async {
  final (db, local) = await openTestLocalData();
  addTearDown(db.close);
  await local.ensureReadingHistoryLoaded();
  await local.ensureBlacklistLoaded();
  await local.ensurePollVotesLoaded();

  final router = GoRouter(
    initialLocation: '/thread/$tid',
    routes: [
      GoRoute(
        path: '/thread/:tid',
        builder: (context, state) {
          return ThreadDetailScreen(
            tid: state.pathParameters['tid']!,
            onDestinationChanged: (_) {},
          );
        },
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        localDataProvider.overrideWithValue(local),
        settingsProvider.overrideWith(
          () => SettingsNotifier(
            initial: const AppSettings(
              showImages: false,
              recordReadingHistory: false,
            ),
          ),
        ),
        threadRateLogsProvider(tid)
            .overrideWith(() => _TestThreadRateLogsNotifier(tid)),
        postProvider(tid).overrideWith(() => notifier),
      ],
      child: MaterialApp.router(
        theme: AppTheme.lightTheme('purple'),
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'thread detail shows pull-to-refresh and keeps overflow refresh',
    (tester) async {
      final notifier = _FakePostNotifier('200');
      await _pumpThread(tester: tester, tid: '200', notifier: notifier);

      expect(find.text('楼层正文'), findsOneWidget);
      expect(find.byType(RefreshIndicator), findsOneWidget);

      final moreMenuFinder = find.descendant(
        of: find.byType(AppBarMoreMenu),
        matching: find.byTooltip('更多操作'),
      );
      await tester.tap(moreMenuFinder);
      await tester.pumpAndSettle();
      expect(find.text('刷新'), findsOneWidget);
    },
  );

  testWidgets('empty thread page list can overscroll for pull-to-refresh', (
    tester,
  ) async {
    final notifier = _FakePostNotifier('201', empty: true);
    await _pumpThread(tester: tester, tid: '201', notifier: notifier);

    expect(find.text('暂无回复'), findsOneWidget);
    expect(find.byType(RefreshIndicator), findsOneWidget);

    final listView = tester.widget<ListView>(find.byType(ListView).first);
    expect(listView.physics, isA<AlwaysScrollableScrollPhysics>());
  });

  testWidgets(
    'last incomplete page shows refresh hint and can refresh from end',
    (tester) async {
      final notifier = _FakePostNotifier('202', lastPageIncomplete: true);
      await _pumpThread(tester: tester, tid: '202', notifier: notifier);

      expect(find.text('最后一贴'), findsOneWidget);
      expect(find.text('已是末页 · 再拉刷新'), findsOneWidget);

      final pagination = tester.widget<S1SwipePagination>(
        find.byType(S1SwipePagination),
      );
      expect(pagination.onTerminalRefresh, isNotNull);
      await pagination.onTerminalRefresh!();
      expect(notifier.refreshCount, 1);
    },
  );

  testWidgets('mid-page footer does not promise end refresh', (tester) async {
    final notifier = _FakePostNotifier('203');
    await _pumpThread(tester: tester, tid: '203', notifier: notifier);

    expect(find.text('本页到底 · 左滑或点下一页'), findsOneWidget);
    expect(find.textContaining('再拉刷新'), findsNothing);
  });

  test('resolveThreadEndRefreshOutcome covers last-page growth cases', () {
    expect(
      resolveThreadEndRefreshOutcome(
        previousReplyCount: 22,
        previousPostCount: 2,
        currentPage: 3,
        totalPages: 4,
        totalReplies: 31,
        postCount: 10,
      ),
      ThreadEndRefreshOutcome.jumpedToNewLastPage,
    );
    expect(
      resolveThreadEndRefreshOutcome(
        previousReplyCount: 22,
        previousPostCount: 2,
        currentPage: 3,
        totalPages: 3,
        totalReplies: 23,
        postCount: 3,
      ),
      ThreadEndRefreshOutcome.scrolledToNewPosts,
    );
    expect(
      resolveThreadEndRefreshOutcome(
        previousReplyCount: 22,
        previousPostCount: 2,
        currentPage: 3,
        totalPages: 3,
        totalReplies: 22,
        postCount: 2,
      ),
      ThreadEndRefreshOutcome.noNewReplies,
    );
  });
}
