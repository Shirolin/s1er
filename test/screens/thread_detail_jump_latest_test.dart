import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:s1er/models/post.dart';
import 'package:s1er/providers/in_thread_jump_provider.dart';
import 'package:s1er/providers/post_provider.dart';
import 'package:s1er/providers/settings_provider.dart';
import 'package:s1er/providers/thread_rate_logs_provider.dart';
import 'package:s1er/screens/thread_detail_screen.dart';
import 'package:s1er/widgets/app_bar_more_menu.dart';
import 'package:s1er/theme/app_theme.dart';
import 'package:s1er/models/rate_log.dart';

import '../helpers/test_local_data.dart';

class _TestThreadRateLogsNotifier extends ThreadRateLogsNotifier {
  _TestThreadRateLogsNotifier(super.tid);

  @override
  Map<String, PostRateLog> build() => const {};
}

class _FakePostNotifier extends PostNotifier {
  _FakePostNotifier(super.tid);

  int goToPageCallCount = 0;
  int _currentPage = 1;

  @override
  Future<PostListState> build() async {
    return PostListState(
      posts: _makePosts(page: _currentPage),
      currentPage: _currentPage,
      totalPages: 3,
      perPage: 10,
      totalReplies: 30,
      threadSubject: '测试主题',
    );
  }

  @override
  Future<void> goToPage(int page) async {
    goToPageCallCount++;
    _currentPage = page;
    state = AsyncValue.data(
      PostListState(
        posts: _makePosts(page: page),
        currentPage: page,
        totalPages: 3,
        perPage: 10,
        totalReplies: 30,
        threadSubject: '测试主题',
      ),
    );
  }

  @override
  Future<bool> restoreToFloor({
    required int page,
    required int absoluteFloor,
  }) async {
    _currentPage = page;
    state = AsyncValue.data(
      PostListState(
        posts: _makePosts(page: page),
        currentPage: page,
        totalPages: 3,
        perPage: 10,
        totalReplies: 30,
        threadSubject: '测试主题',
      ),
    );
    return true;
  }

  @override
  Future<void> refresh() async {
    final current = state.asData?.value.currentPage ?? 1;
    state = AsyncValue.data(
      PostListState(
        posts: _makePosts(page: current),
        currentPage: current,
        totalPages: 3,
        perPage: 10,
        totalReplies: 30,
        threadSubject: '测试主题',
      ),
    );
  }

  static List<Post> _makePosts({required int page}) {
    return List.generate(
      10,
      (i) => Post(
        pid: '${(page - 1) * 10 + i + 1}',
        author: '用户 $i',
        authorId: '$i',
        message: '这是第 $page 页的第 ${i + 1} 楼内容',
        dateline: 1700000000,
        floor: (page - 1) * 10 + i + 1,
      ),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('跳转到最新：在第 1 页点击跳转至最后一页，且支持从跳转栈恢复', (tester) async {
    final (db, local) = await openTestLocalData();
    addTearDown(db.close);
    await local.ensureReadingHistoryLoaded();
    await local.ensureBlacklistLoaded();
    await local.ensurePollVotesLoaded();

    final fakeNotifier = _FakePostNotifier('100');

    final router = GoRouter(
      initialLocation: '/thread/100',
      routes: [
        GoRoute(
          path: '/thread/:tid',
          builder: (context, state) {
            final routeTid = state.pathParameters['tid']!;
            return ThreadDetailScreen(
              tid: routeTid,
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
          threadRateLogsProvider('100').overrideWith(
            () => _TestThreadRateLogsNotifier('100'),
          ),
          postProvider('100').overrideWith(() => fakeNotifier),
        ],
        child: MaterialApp.router(
          theme: AppTheme.lightTheme('purple'),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 确认当前在第 1 页
    expect(find.text('这是第 1 页的第 1 楼内容'), findsOneWidget);

    // 打开 Header 菜单并点击【跳转到最新】
    final moreMenuFinder = find.descendant(
      of: find.byType(AppBarMoreMenu),
      matching: find.byTooltip('更多操作'),
    );
    await tester.tap(moreMenuFinder);
    await tester.pumpAndSettle();

    expect(find.text('跳转到最新'), findsOneWidget);
    await tester.tap(find.text('跳转到最新'));
    await tester.pump();
    await tester.pumpAndSettle();

    // 校验切换到第 3 页，且由于自动置底最新楼层（第 10 楼）在视口可见
    expect(fakeNotifier.goToPageCallCount, 1);
    expect(
      find.text('这是第 3 页的第 1 楼内容', skipOffstage: false),
      findsOneWidget,
    );

    // 校验跳转前的阅读位置已压入 inThreadJumpStack
    final element = tester.element(find.byType(ThreadDetailScreen));
    final container = ProviderScope.containerOf(element);
    final jumpStack = container.read(inThreadJumpStackProvider('100'));
    expect(jumpStack, isNotEmpty);
    expect(jumpStack.last.page, 1);

    // 点击 Appbar 返回按键弹栈恢复到第 1 页
    await tester.tap(find.byTooltip('返回上一位置'));
    await tester.pumpAndSettle();

    expect(
      find.text('这是第 1 页的第 1 楼内容', skipOffstage: false),
      findsOneWidget,
    );
  });
}
