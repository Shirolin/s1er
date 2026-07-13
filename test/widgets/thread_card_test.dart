import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s1_app/models/reading_record.dart';
import 'package:s1_app/models/thread.dart';
import 'package:s1_app/providers/auth_provider.dart';
import 'package:s1_app/providers/reading_history_provider.dart';
import 'package:s1_app/providers/settings_provider.dart';
import 'package:s1_app/services/app_database.dart';
import 'package:s1_app/services/app_local_data.dart';
import 'package:s1_app/theme/app_theme.dart';
import 'package:s1_app/widgets/thread_card.dart';

Thread _sampleThread({String subject = 'Sample Thread'}) {
  return Thread(
    tid: '123',
    subject: subject,
    author: 'alice',
    authorId: '1',
    dateline: 1700000000,
    views: 100,
    replies: 5,
    fid: '4',
  );
}

void main() {
  testWidgets('ThreadCard renders title, author and reply count', (tester) async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(() => db.close());
    final local = AppLocalData(db);
    await local.load();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localDataProvider.overrideWithValue(local),
          authStateProvider.overrideWith(_IdleAuthNotifier.new),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme('purple'),
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 400,
                child: ThreadCard(thread: _sampleThread()),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Sample Thread'), findsOneWidget);
    expect(find.textContaining('alice'), findsOneWidget);
    expect(find.textContaining('5'), findsWidgets);
  });

  testWidgets('ThreadCard shows reading progress when record exists',
      (tester) async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(() => db.close());
    final local = AppLocalData(db);
    await local.load();

    final container = ProviderContainer(
      overrides: [
        localDataProvider.overrideWithValue(local),
        authStateProvider.overrideWith(_IdleAuthNotifier.new),
      ],
    );
    addTearDown(container.dispose);
    await container.read(readingHistoryBootstrapProvider.future);
    container.read(readingHistoryProvider.notifier).upsert(
          ReadingRecord(
            tid: '123',
            subject: 'Sample Thread',
            author: 'alice',
            fid: '4',
            lastReadPage: 1,
            lastReadFloor: 10,
            totalPages: 3,
            totalReplies: 80,
            perPage: 40,
            lastReadAt: 2000,
            firstReadAt: 1000,
          ),
        );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.lightTheme('purple'),
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 400,
                child: ThreadCard(thread: _sampleThread()),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('已读'), findsOneWidget);
  });
}

class _IdleAuthNotifier extends AuthNotifier {
  @override
  AuthState build() => AuthState();
}
