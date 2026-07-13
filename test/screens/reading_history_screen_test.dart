import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s1_app/models/reading_record.dart';
import 'package:s1_app/providers/reading_history_provider.dart';
import 'package:s1_app/providers/settings_provider.dart';
import 'package:s1_app/screens/reading_history_screen.dart';
import 'package:s1_app/services/app_database.dart';
import 'package:s1_app/services/app_local_data.dart';
import 'package:s1_app/theme/app_theme.dart';

ReadingRecord _sampleRecord() {
  return ReadingRecord(
    tid: '100',
    subject: '测试主题',
    author: 'alice',
    fid: '4',
    lastReadPage: 2,
    lastReadFloor: 5,
    totalPages: 3,
    totalReplies: 80,
    perPage: 40,
    lastReadAt: 2000,
    firstReadAt: 1000,
  );
}

void main() {
  late AppDatabase db;
  late AppLocalData local;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    db = AppDatabase.forTesting(NativeDatabase.memory());
    local = AppLocalData(db);
    await local.load();
  });

  tearDown(() async {
    await db.close();
  });

  testWidgets('ReadingHistoryScreen shows empty state', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localDataProvider.overrideWithValue(local),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme('purple'),
          home: const ReadingHistoryScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('阅读历史'), findsOneWidget);
    expect(find.text('暂无阅读记录'), findsOneWidget);
  });

  testWidgets('ReadingHistoryScreen shows records when history exists',
      (tester) async {
    final container = ProviderContainer(
      overrides: [
        localDataProvider.overrideWithValue(local),
      ],
    );
    addTearDown(container.dispose);
    await container.read(readingHistoryBootstrapProvider.future);
    container.read(readingHistoryProvider.notifier).upsert(_sampleRecord());

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.lightTheme('purple'),
          home: const ReadingHistoryScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('测试主题'), findsOneWidget);
    expect(find.byIcon(Icons.delete_sweep_outlined), findsOneWidget);
  });
}
