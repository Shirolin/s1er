import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s1er/models/blacklist_record.dart';
import 'package:s1er/models/user_space_item.dart';
import 'package:s1er/providers/auth_provider.dart';
import 'package:s1er/providers/blacklist_provider.dart';
import 'package:s1er/providers/user_space_provider.dart';
import 'package:s1er/screens/user_space_screen.dart';
import 'package:s1er/theme/app_theme.dart';

class _GuestAuth extends AuthNotifier {
  @override
  AuthState build() => AuthState();
}

class _EmptyBlacklist extends BlacklistNotifier {
  @override
  List<BlacklistRecord> build() => const [];
}

class _FakeReplies extends UserSpaceRepliesNotifier {
  _FakeReplies(super.params, this.result);

  final UserSpaceListResult result;

  @override
  Future<UserSpaceListResult> fetchPage(int page) async => result;
}

void main() {
  testWidgets('reply card folds entries beyond the visible limit',
      (tester) async {
    final item = UserSpaceItem(
      tid: '100',
      subject: '聚合主题',
      forumName: '游戏区',
      dateline: 1720000000,
      replyEntries: [
        for (var i = 1; i <= 5; i++)
          UserSpaceReplyEntry(pid: '$i', excerpt: '回复内容$i'),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith(_GuestAuth.new),
          blacklistProvider.overrideWith(_EmptyBlacklist.new),
          userSpaceRepliesProvider(('1', false)).overrideWith(
            () => _FakeReplies(
              ('1', false),
              UserSpaceListResult(items: [item]),
            ),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme('sand'),
          home: const UserSpaceScreen(
            uid: '1',
            username: 'Alice',
            initialTab: 1,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Alice 的空间'), findsOneWidget);
    expect(find.text('聚合主题'), findsOneWidget);
    expect(find.text('回复内容1'), findsOneWidget);
    expect(find.text('回复内容2'), findsOneWidget);
    expect(find.text('回复内容3'), findsOneWidget);
    expect(find.text('回复内容4'), findsNothing);
    expect(find.text('还有 2 条回复'), findsOneWidget);
  });
}
