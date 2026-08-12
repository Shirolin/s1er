import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:s1er/models/pinned_thread.dart';
import 'package:s1er/providers/settings_provider.dart';
import 'package:s1er/services/app_database.dart';
import 'package:s1er/services/app_local_data.dart';
import 'package:s1er/theme/app_theme.dart';
import 'package:s1er/widgets/pinned_threads_section.dart';
import 'package:drift/native.dart';

void main() {
  Future<AppLocalData> openLocal() async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final localData = AppLocalData(db);
    await localData.load();
    addTearDown(() async => db.close());
    return localData;
  }

  testWidgets('single pinned thread can collapse and expand', (tester) async {
    final localData = await openLocal();

    final threads = [
      const PinnedThread(
        tid: '1',
        title: '唯一置顶帖',
        pinnedAt: 1,
        displayOrder: 0,
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localDataProvider.overrideWithValue(localData),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme('purple'),
          home: Scaffold(
            body: PinnedThreadsSection(threads: threads),
          ),
        ),
      ),
    );

    expect(find.text('唯一置顶帖'), findsOneWidget);

    await tester.tap(find.byTooltip('收起'));
    await tester.pumpAndSettle();

    expect(find.text('唯一置顶帖'), findsNothing);

    await tester.tap(find.byTooltip('展开'));
    await tester.pumpAndSettle();

    expect(find.text('唯一置顶帖'), findsOneWidget);
  });

  testWidgets('shows manage button for single thread', (tester) async {
    final localData = await openLocal();

    final threads = [
      const PinnedThread(
        tid: '1',
        title: '测试帖',
        pinnedAt: 1,
        displayOrder: 0,
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localDataProvider.overrideWithValue(localData),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme('purple'),
          home: Scaffold(
            body: PinnedThreadsSection(threads: threads),
          ),
        ),
      ),
    );

    expect(find.byTooltip('管理'), findsOneWidget);
    expect(find.byIcon(Icons.reorder), findsOneWidget);
  });

  testWidgets('shows new-reply badge when live is ahead of lastSeen',
      (tester) async {
    final localData = await openLocal();
    final threads = [
      const PinnedThread(
        tid: '42',
        title: '高楼',
        pinnedAt: 1,
        displayOrder: 0,
        lastKnownReplies: 150,
        lastSeenReplies: 120,
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localDataProvider.overrideWithValue(localData),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme('purple'),
          home: Scaffold(
            body: PinnedThreadsSection(threads: threads),
          ),
        ),
      ),
    );

    expect(find.text('30'), findsOneWidget);
    expect(find.byType(Badge), findsOneWidget);
  });

  testWidgets('hides badge when lastSeen is missing', (tester) async {
    final localData = await openLocal();
    final threads = [
      const PinnedThread(
        tid: '42',
        title: '高楼',
        pinnedAt: 1,
        displayOrder: 0,
        lastKnownReplies: 150,
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localDataProvider.overrideWithValue(localData),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme('purple'),
          home: Scaffold(
            body: PinnedThreadsSection(threads: threads),
          ),
        ),
      ),
    );

    expect(find.byType(Badge), findsNothing);
  });

  testWidgets('hides badge when live equals lastSeen', (tester) async {
    final localData = await openLocal();
    final threads = [
      const PinnedThread(
        tid: '42',
        title: '高楼',
        pinnedAt: 1,
        displayOrder: 0,
        lastKnownReplies: 120,
        lastSeenReplies: 120,
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localDataProvider.overrideWithValue(localData),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme('purple'),
          home: Scaffold(
            body: PinnedThreadsSection(threads: threads),
          ),
        ),
      ),
    );

    expect(find.byType(Badge), findsNothing);
  });
}
