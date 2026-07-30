import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s1er/models/pinned_thread.dart';
import 'package:s1er/models/thread.dart';
import 'package:s1er/models/user.dart';
import 'package:s1er/providers/auth_provider.dart';
import 'package:s1er/providers/favorite_membership_provider.dart';
import 'package:s1er/providers/pinned_threads_provider.dart';
import 'package:s1er/providers/settings_provider.dart';
import 'package:s1er/widgets/thread_context_sheet.dart';

import '../helpers/test_theme.dart';

void main() {
  final thread = Thread(
    tid: '100',
    subject: 'Switch 2 斯普拉遁涂击队 7月23日发售',
    author: '测试用户',
    authorId: '1',
    dateline: 1700000000,
    views: 1200,
    replies: 189,
    fid: '4',
  );

  Future<void> pumpSheet(
    WidgetTester tester, {
    required bool loggedIn,
    bool favorited = false,
    bool pinned = false,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith(
            loggedIn ? _LoggedInAuthNotifier.new : _LoggedOutAuthNotifier.new,
          ),
          settingsProvider.overrideWith(
            () => SettingsNotifier(initial: const AppSettings()),
          ),
          favoriteMembershipProvider.overrideWith(
            () => _TestMembershipNotifier(favorited: favorited),
          ),
          pinnedThreadsProvider.overrideWith(
            () => _TestPinnedNotifier(
              items: pinned
                  ? [
                      PinnedThread(
                        tid: thread.tid,
                        title: thread.subject,
                        pinnedAt: 1,
                        displayOrder: 0,
                      ),
                    ]
                  : const [],
            ),
          ),
        ],
        child: wrapWithAppTheme(_SheetLauncher(thread: thread)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('shows pin, favorite, and page jump actions', (tester) async {
    await pumpSheet(tester, loggedIn: true);

    expect(find.text('钉在首页'), findsOneWidget);
    expect(find.text('收藏帖子'), findsOneWidget);
    expect(find.text('跳转到某页'), findsOneWidget);
    expect(find.textContaining('共'), findsWidgets);
  });

  testWidgets('reflects pinned and favorited state labels', (tester) async {
    await pumpSheet(
      tester,
      loggedIn: true,
      favorited: true,
      pinned: true,
    );

    expect(find.text('取消置顶'), findsOneWidget);
    expect(find.text('取消收藏'), findsOneWidget);
  });

  testWidgets('jump to page opens picker instead of entering thread',
      (tester) async {
    await pumpSheet(tester, loggedIn: true);

    await tester.tap(find.text('跳转到某页'));
    await tester.pump();
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('选择页码'), findsOneWidget);
    expect(find.text('跳转'), findsOneWidget);
  });
}

class _SheetLauncher extends ConsumerWidget {
  const _SheetLauncher({required this.thread});

  final Thread thread;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FilledButton(
      onPressed: () => showThreadContextSheet(
        context: context,
        ref: ref,
        thread: thread,
      ),
      child: const Text('open'),
    );
  }
}

class _LoggedInAuthNotifier extends AuthNotifier {
  @override
  AuthState build() => AuthState(
        isLoggedIn: true,
        username: 'tester',
        user: User(uid: '1', username: 'tester'),
      );
}

class _LoggedOutAuthNotifier extends AuthNotifier {
  @override
  AuthState build() => AuthState(isLoggedIn: false);
}

class _TestMembershipNotifier extends FavoriteMembershipNotifier {
  _TestMembershipNotifier({required this.favorited});

  final bool favorited;

  @override
  FavoriteMembershipState build() {
    if (!favorited) return const FavoriteMembershipState();
    return const FavoriteMembershipState(
      keys: {'thread:100'},
      favids: {'thread:100': 'fav1'},
    );
  }

  @override
  Future<void> ensureSynced() async {}
}

class _TestPinnedNotifier extends PinnedThreadsNotifier {
  _TestPinnedNotifier({required this.items});

  final List<PinnedThread> items;

  @override
  List<PinnedThread> build() => items;
}
