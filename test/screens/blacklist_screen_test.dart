import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s1er/providers/settings_provider.dart';
import 'package:s1er/screens/blacklist_screen.dart';
import 'package:s1er/services/app_database.dart';
import 'package:s1er/services/app_local_data.dart';
import 'package:s1er/theme/app_theme.dart';

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
    await local.flushPendingWrites();
    await db.close();
  });

  testWidgets('shows empty state when no entries', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localDataProvider.overrideWithValue(local),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme('purple'),
          home: const BlacklistScreen(),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('暂无屏蔽用户'), findsOneWidget);
    expect(find.text('添加'), findsOneWidget);
  });
}
