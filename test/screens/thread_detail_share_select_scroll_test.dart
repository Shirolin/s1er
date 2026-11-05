import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:s1er/models/post.dart';
import 'package:s1er/models/rate_log.dart';
import 'package:s1er/providers/post_provider.dart';
import 'package:s1er/providers/settings_provider.dart';
import 'package:s1er/providers/thread_rate_logs_provider.dart';
import 'package:s1er/screens/thread_detail_screen.dart';
import 'package:s1er/theme/app_theme.dart';
import 'package:s1er/widgets/post_item.dart';

import '../helpers/test_local_data.dart';

class _TestThreadRateLogsNotifier extends ThreadRateLogsNotifier {
  _TestThreadRateLogsNotifier(super.tid);

  @override
  Map<String, PostRateLog> build() => const {};
}

class _ManyPostsNotifier extends PostNotifier {
  _ManyPostsNotifier(super.tid, {required this.totalPages});

  final int totalPages;

  @override
  Future<PostListState> build() async {
    return PostListState(
      posts: [
        for (var i = 1; i <= 20; i++)
          Post(
            pid: '$i',
            author: '用户$i',
            authorId: '$i',
            message: '第 $i 楼正文',
            dateline: 1700000000 + i,
            floor: i,
          ),
      ],
      currentPage: 1,
      totalPages: totalPages,
      perPage: 20,
      totalReplies: 39,
      threadSubject: '多选分享测试',
    );
  }

  @override
  Future<void> refresh() async {}
}

Future<void> _pumpThread(
  WidgetTester tester,
  String tid, {
  required int totalPages,
}) async {
  tester.view.physicalSize = const Size(390, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

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
        builder: (context, state) => ThreadDetailScreen(
          tid: state.pathParameters['tid']!,
          onDestinationChanged: (_) {},
        ),
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
        postProvider(tid).overrideWith(
          () => _ManyPostsNotifier(tid, totalPages: totalPages),
        ),
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

  Future<void> expectScrollKept(
    WidgetTester tester, {
    required String tid,
    required int totalPages,
  }) async {
    await _pumpThread(tester, tid, totalPages: totalPages);

    final list = find.byType(ListView).first;
    final controller = tester.widget<ListView>(list).controller!;
    controller.jumpTo(900);
    await tester.pumpAndSettle();

    final offsetBefore = controller.offset;
    expect(offsetBefore, greaterThan(0));

    final menuButton = find
        .descendant(
          of: find.byType(PostItem),
          matching: find.byTooltip('更多操作'),
        )
        .hitTestable()
        .first;
    await tester.tap(menuButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text('多选分享').last);
    await tester.pumpAndSettle();

    expect(find.textContaining('已选 1/'), findsOneWidget);
    expect(controller.offset, closeTo(offsetBefore, 1));
  }

  testWidgets('进入多选分享后保持当前滚动位置（多页）', (tester) async {
    await expectScrollKept(tester, tid: '300', totalPages: 2);
  });

  testWidgets('进入多选分享后保持当前滚动位置（单页/末页）', (tester) async {
    await expectScrollKept(tester, tid: '301', totalPages: 1);
  });
}
