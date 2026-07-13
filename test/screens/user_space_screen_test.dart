import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s1_app/models/user_space_item.dart';
import 'package:s1_app/providers/auth_provider.dart';
import 'package:s1_app/providers/user_space_provider.dart';
import 'package:s1_app/screens/user_space_screen.dart';
import 'package:s1_app/theme/app_theme.dart';

void main() {
  const params = ('42', false);

  testWidgets('UserSpaceScreen shows loading state', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith(_IdleAuthNotifier.new),
          userSpaceProvider(params).overrideWith(() => _LoadingUserSpaceNotifier()),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme('purple'),
          home: const UserSpaceScreen(uid: '42', username: 'alice'),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('alice 的空间'), findsOneWidget);
    expect(find.text('主题'), findsOneWidget);
    expect(find.text('回复'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
  });

  testWidgets('UserSpaceScreen shows thread tab content when loaded',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith(_IdleAuthNotifier.new),
          userSpaceProvider(params).overrideWith(() => _LoadedUserSpaceNotifier()),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme('purple'),
          home: const UserSpaceScreen(uid: '42', username: 'alice'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Space Thread'), findsOneWidget);
  });

  testWidgets('UserSpaceScreen switches to replies tab', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith(_IdleAuthNotifier.new),
          userSpaceProvider(params).overrideWith(() => _LoadedUserSpaceNotifier()),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme('purple'),
          home: const UserSpaceScreen(uid: '42', username: 'alice'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('回复'));
    await tester.pumpAndSettle();

    expect(find.text('Reply excerpt'), findsOneWidget);
  });
}

class _IdleAuthNotifier extends AuthNotifier {
  @override
  AuthState build() => AuthState();
}

class _LoadingUserSpaceNotifier extends UserSpaceNotifier {
  _LoadingUserSpaceNotifier() : super(('42', false));

  final _completer = Completer<UserSpaceState>();

  @override
  Future<UserSpaceState> build() => _completer.future;
}

class _LoadedUserSpaceNotifier extends UserSpaceNotifier {
  _LoadedUserSpaceNotifier() : super(('42', false));

  @override
  Future<UserSpaceState> build() async {
    return UserSpaceState(
      threads: [
        UserSpaceItem(
          tid: '1',
          subject: 'Space Thread',
          dateline: 1700000000,
        ),
      ],
      replies: [
        UserSpaceItem(
          tid: '2',
          subject: 'Reply Thread',
          dateline: 1700000001,
          isReply: true,
          replyExcerpt: 'Reply excerpt',
          pid: '99',
        ),
      ],
      repliesLoaded: true,
    );
  }

  @override
  Future<void> ensureRepliesLoaded() async {}
}
