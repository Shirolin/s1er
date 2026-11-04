import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:s1er/models/post.dart';
import 'package:s1er/models/rate_log.dart';
import 'package:s1er/models/thread.dart';
import 'package:s1er/models/user.dart';
import 'package:s1er/providers/auth_provider.dart';
import 'package:s1er/providers/forum_name_provider.dart';
import 'package:s1er/providers/post_provider.dart';
import 'package:s1er/providers/settings_provider.dart';
import 'package:s1er/providers/thread_list_provider.dart';
import 'package:s1er/providers/thread_rate_logs_provider.dart';
import 'package:s1er/screens/forum_list_screen.dart';
import 'package:s1er/screens/thread_detail_screen.dart';
import 'package:s1er/screens/thread_route_screen.dart';
import 'package:s1er/theme/app_theme.dart';
import 'package:s1er/utils/thread_navigation.dart';
import 'package:s1er/widgets/forum_split_pane_divider.dart';
import 'package:s1er/widgets/thread_card.dart';

import '../helpers/test_local_data.dart';

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

class _FakePostNotifier extends PostNotifier {
  _FakePostNotifier(super.tid, this.fid);

  final String? fid;

  @override
  Future<PostListState> build() async {
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
      totalPages: 1,
      perPage: 10,
      totalReplies: 0,
      threadSubject: '测试主题',
      threadFid: fid,
    );
  }
}

class _FakeThreadListNotifier extends ThreadListNotifier {
  _FakeThreadListNotifier(super.fid);

  @override
  Future<ThreadListState> build() async {
    return ThreadListState(
      threads: [
        Thread(
          tid: '100',
          subject: '测试主题',
          author: '用户',
          authorId: '1',
          dateline: 1700000000,
          views: 0,
          replies: 0,
          fid: fid,
        ),
      ],
      sourceThreads: const [],
      forumName: '游戏论坛',
    );
  }
}

class _TestThreadRateLogsNotifier extends ThreadRateLogsNotifier {
  _TestThreadRateLogsNotifier(super.tid);

  @override
  Map<String, PostRateLog> build() => const {};
}

Future<GoRouter> _pumpRouteScreen(
  WidgetTester tester, {
  required Size size,
  required String? fid,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final (db, local) = await openTestLocalData();
  addTearDown(db.close);
  await local.ensureReadingHistoryLoaded();

  final router = GoRouter(
    initialLocation: '/thread/100',
    routes: [
      GoRoute(
        path: '/thread/:tid',
        pageBuilder: (context, state) {
          final tid = state.pathParameters['tid']!;
          return NoTransitionPage<void>(
            key: state.pageKey,
            child: ThreadRouteScreen(
              tid: tid,
              intent: ThreadRouteCodec.intentFromUri(state.uri, tid: tid),
              fidHint:
                  state.uri.queryParameters[ThreadRouteCodec.threadFidQuery],
            ),
          );
        },
      ),
      GoRoute(
        path: '/',
        builder: (context, state) => const Scaffold(body: SizedBox()),
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
        authStateProvider.overrideWith(_GuestAuthNotifier.new),
        threadRateLogsProvider('100')
            .overrideWith(() => _TestThreadRateLogsNotifier('100')),
        postProvider('100').overrideWith(() => _FakePostNotifier('100', fid)),
        threadListProvider('4')
            .overrideWith(() => _FakeThreadListNotifier('4')),
        fidToForumNameMapProvider.overrideWithValue(const {'4': '游戏论坛'}),
      ],
      child: MaterialApp.router(
        theme: AppTheme.lightTheme('purple'),
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('wide direct thread entry shows forum split view',
      (tester) async {
    await _pumpRouteScreen(tester, size: const Size(1400, 900), fid: '4');

    expect(find.byType(ForumSplitPaneDivider), findsOneWidget);
    expect(find.byType(ForumListScreen), findsOneWidget);
    expect(find.byType(ThreadDetailScreen), findsOneWidget);
    expect(find.text('楼层正文'), findsOneWidget);
  });

  testWidgets('wide entry without resolved forum fid stays single pane',
      (tester) async {
    await _pumpRouteScreen(tester, size: const Size(1400, 900), fid: null);

    expect(find.byType(ForumSplitPaneDivider), findsNothing);
    expect(find.byType(ForumListScreen), findsNothing);
    expect(find.byType(ThreadDetailScreen), findsOneWidget);
  });

  testWidgets('compact width keeps single-pane thread detail', (tester) async {
    await _pumpRouteScreen(tester, size: const Size(800, 1200), fid: '4');

    expect(find.byType(ForumSplitPaneDivider), findsNothing);
    expect(find.byType(ForumListScreen), findsNothing);
    expect(find.byType(ThreadDetailScreen), findsOneWidget);
  });

  testWidgets('selecting a thread in the split keeps the thread route',
      (tester) async {
    final router =
        await _pumpRouteScreen(tester, size: const Size(1400, 900), fid: '4');

    await tester.tap(find.byType(ThreadCard).first);
    await tester.pumpAndSettle();

    expect(find.byType(ForumSplitPaneDivider), findsOneWidget);
    expect(router.state.uri.path, '/thread/100');
    expect(
      router.state.uri.queryParameters[ThreadRouteCodec.threadFidQuery],
      '4',
    );
  });
}
