import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s1_app/models/thread.dart';
import 'package:s1_app/providers/auth_provider.dart';
import 'package:s1_app/providers/favorite_membership_provider.dart';
import 'package:s1_app/providers/forum_name_provider.dart';
import 'package:s1_app/providers/settings_provider.dart';
import 'package:s1_app/providers/thread_list_provider.dart';
import 'package:s1_app/screens/forum_list_screen.dart';
import 'package:s1_app/services/app_database.dart';
import 'package:s1_app/services/app_local_data.dart';
import 'package:s1_app/theme/app_theme.dart';

void main() {
  const fid = '4';
  late AppLocalData local;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    local = AppLocalData(db);
    await local.load();
  });

  testWidgets('ForumListScreen shows loading indicator', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localDataProvider.overrideWithValue(local),
          authStateProvider.overrideWith(_IdleAuthNotifier.new),
          threadListProvider(fid).overrideWith(() => _LoadingThreadListNotifier()),
          forumNameProvider(fid).overrideWith((ref) => '游戏论坛'),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme('purple'),
          home: const ForumListScreen(fid: fid),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.text('游戏论坛'), findsOneWidget);
  });

  testWidgets('ForumListScreen shows thread list when loaded', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localDataProvider.overrideWithValue(local),
          authStateProvider.overrideWith(_IdleAuthNotifier.new),
          threadListProvider(fid).overrideWith(() => _LoadedThreadListNotifier()),
          forumNameProvider(fid).overrideWith((ref) => '游戏论坛'),
          favoriteMembershipProvider.overrideWith(() => _IdleFavoriteMembershipNotifier()),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme('purple'),
          home: const ForumListScreen(fid: fid),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('游戏论坛'), findsOneWidget);
    expect(find.text('Test Thread'), findsOneWidget);
  });

  testWidgets('ForumListScreen shows error view on failure', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localDataProvider.overrideWithValue(local),
          authStateProvider.overrideWith(_IdleAuthNotifier.new),
          threadListProvider(fid).overrideWith(() => _ErrorThreadListNotifier()),
          forumNameProvider(fid).overrideWith((ref) => null),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme('purple'),
          home: const ForumListScreen(fid: fid),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('版块 #$fid'), findsOneWidget);
    expect(find.text('重试'), findsOneWidget);
  });
}

class _IdleAuthNotifier extends AuthNotifier {
  @override
  AuthState build() => AuthState();
}

class _IdleFavoriteMembershipNotifier extends FavoriteMembershipNotifier {
  @override
  FavoriteMembershipState build() => const FavoriteMembershipState();
}

class _LoadingThreadListNotifier extends ThreadListNotifier {
  _LoadingThreadListNotifier() : super('4');

  final _completer = Completer<ThreadListState>();

  @override
  Future<ThreadListState> build() => _completer.future;
}

class _LoadedThreadListNotifier extends ThreadListNotifier {
  _LoadedThreadListNotifier() : super('4');

  @override
  Future<ThreadListState> build() async {
    return ThreadListState(
      forumName: '游戏论坛',
      threads: [
        Thread(
          tid: '123',
          subject: 'Test Thread',
          author: 'alice',
          authorId: '1',
          dateline: 1700000000,
          views: 10,
          replies: 2,
          fid: '4',
        ),
      ],
    );
  }
}

class _ErrorThreadListNotifier extends ThreadListNotifier {
  _ErrorThreadListNotifier() : super('4');

  @override
  Future<ThreadListState> build() async {
    throw Exception('network failed');
  }
}
