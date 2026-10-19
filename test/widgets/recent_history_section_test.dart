import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:s1er/models/forum_category.dart';
import 'package:s1er/models/reading_history_state.dart';
import 'package:s1er/models/reading_record.dart';
import 'package:s1er/providers/forum_list_provider.dart';
import 'package:s1er/providers/reading_history_provider.dart';
import 'package:s1er/providers/settings_provider.dart';
import 'package:s1er/theme/app_theme.dart';
import 'package:s1er/widgets/recent_history_section.dart';

import '../helpers/test_theme.dart';

void main() {
  testWidgets('renders nothing when there is no reading history',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: wrapWithAppTheme(const RecentHistorySection()),
      ),
    );
    await tester.pump();

    expect(find.text('最近浏览'), findsNothing);
  });

  testWidgets('shows at most three recent records', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          readingHistoryProvider.overrideWith(
            () => _FixedHistoryNotifier([
              _record(tid: '1', subject: '甲'),
              _record(tid: '2', subject: '乙'),
              _record(tid: '3', subject: '丙'),
              _record(tid: '4', subject: '丁'),
            ]),
          ),
          forumListProvider.overrideWith(_NamedForumList.new),
        ],
        child: wrapWithAppTheme(const RecentHistorySection()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('最近浏览'), findsOneWidget);
    expect(find.text('甲'), findsOneWidget);
    expect(find.text('乙'), findsOneWidget);
    expect(find.text('丙'), findsOneWidget);
    expect(find.text('丁'), findsNothing);
    expect(find.text('外野 · 刚刚 · 已读'), findsNWidgets(3));
  });

  testWidgets('hides the section when the home preview setting is off', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith(
            () => SettingsNotifier(
              initial: const AppSettings(showRecentHistoryOnHome: false),
            ),
          ),
          readingHistoryProvider.overrideWith(
            () => _FixedHistoryNotifier([
              _record(tid: '1', subject: '甲'),
            ]),
          ),
        ],
        child: wrapWithAppTheme(const RecentHistorySection()),
      ),
    );
    await tester.pump();

    expect(find.text('最近浏览'), findsNothing);
    expect(find.text('甲'), findsNothing);
  });

  testWidgets('opens the thread at the last read floor', (tester) async {
    String? opened;
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, __) => const Scaffold(body: RecentHistorySection()),
        ),
        GoRoute(
          path: '/thread/:tid',
          builder: (_, state) {
            opened = state.uri.toString();
            return const Scaffold(body: Text('thread-destination'));
          },
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          readingHistoryProvider.overrideWith(
            () => _FixedHistoryNotifier([
              _record(
                tid: 't1',
                subject: '续读帖',
                floor: 15,
                replies: 40,
              ),
            ]),
          ),
        ],
        child: MaterialApp.router(
          theme: AppTheme.lightTheme('sand'),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('#15/41'), findsOneWidget);

    await tester.tap(find.text('续读帖'));
    await tester.pumpAndSettle();

    expect(opened, '/thread/t1?page=2&resume=1');
    expect(find.text('thread-destination'), findsOneWidget);
  });

  testWidgets('全部 opens the reading history page', (tester) async {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, __) => const Scaffold(body: RecentHistorySection()),
        ),
        GoRoute(
          path: '/reading-history',
          builder: (_, __) => const Scaffold(body: Text('history-destination')),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          readingHistoryProvider.overrideWith(
            () => _FixedHistoryNotifier([
              _record(tid: '1', subject: '甲'),
            ]),
          ),
        ],
        child: MaterialApp.router(
          theme: AppTheme.lightTheme('sand'),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('全部'));
    await tester.pumpAndSettle();

    expect(find.text('history-destination'), findsOneWidget);
  });
}

class _FixedHistoryNotifier extends ReadingHistoryNotifier {
  _FixedHistoryNotifier(this._records);

  final List<ReadingRecord> _records;

  @override
  ReadingHistoryState build() => ReadingHistoryState.fromRecords(_records);
}

class _NamedForumList extends ForumListNotifier {
  @override
  Future<List<ForumCategory>> build() async {
    return [
      ForumCategory(
        fid: '4',
        name: '外野',
        description: '',
        threads: 1,
        posts: 1,
      ),
    ];
  }
}

ReadingRecord _record({
  required String tid,
  required String subject,
  int floor = 1,
  int replies = 0,
  String fid = '4',
}) {
  final now = DateTime.now().millisecondsSinceEpoch;
  return ReadingRecord(
    tid: tid,
    subject: subject,
    author: '作者',
    fid: fid,
    lastReadPage: 1,
    lastReadFloor: floor,
    totalPages: 1,
    totalReplies: replies,
    perPage: 10,
    lastReadAt: now,
    firstReadAt: now,
  );
}
