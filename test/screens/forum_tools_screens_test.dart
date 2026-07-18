import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:s1er/models/dark_room_entry.dart';
import 'package:s1er/models/friend_summary.dart';
import 'package:s1er/models/user.dart';
import 'package:s1er/providers/auth_provider.dart';
import 'package:s1er/providers/forum_tools_provider.dart';
import 'package:s1er/screens/dark_room_screen.dart';
import 'package:s1er/screens/friends_screen.dart';
import 'package:s1er/services/forum_tools_service.dart';
import 'package:s1er/services/http_client.dart';
import 'package:s1er/theme/app_theme.dart';

void main() {
  testWidgets('FriendsScreen shows empty state', (tester) async {
    final service = _ScreenFakeService(friends: FriendListResult.empty);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          forumToolsServiceProvider.overrideWithValue(service),
          authStateProvider.overrideWith(
            () => _Auth(
              AuthState(
                isLoggedIn: true,
                username: 'me',
                user: User(uid: '1', username: 'me'),
              ),
            ),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme('purple'),
          home: const FriendsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('暂无好友'), findsOneWidget);
  });

  testWidgets('FriendsScreen shows login gate', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          forumToolsServiceProvider.overrideWithValue(_ScreenFakeService()),
          authStateProvider.overrideWith(() => _Auth(AuthState())),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme('purple'),
          home: const FriendsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('请先登录'), findsOneWidget);
  });

  testWidgets('DarkRoomScreen lists entries and load more', (tester) async {
    final service = _ScreenFakeService();
    String? pushed;
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, __) => const DarkRoomScreen(),
        ),
        GoRoute(
          path: '/user-space/:uid',
          builder: (context, state) {
            pushed = state.pathParameters['uid'];
            return const Scaffold(body: Text('space'));
          },
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          forumToolsServiceProvider.overrideWithValue(service),
        ],
        child: MaterialApp.router(
          theme: AppTheme.lightTheme('purple'),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('example_user'), findsOneWidget);
    expect(find.text('加载更多'), findsOneWidget);

    await tester.tap(find.text('example_user'));
    await tester.pumpAndSettle();
    expect(pushed, '223056');
  });
}

class _Auth extends AuthNotifier {
  _Auth(this.initial);
  final AuthState initial;

  @override
  AuthState build() => initial;
}

class _ScreenFakeService extends ForumToolsService {
  _ScreenFakeService({this.friends})
      : super(S1HttpClient.test(ProviderContainer(), Dio()));

  final FriendListResult? friends;

  @override
  Future<FriendListResult> getFriendList({required String uid}) async {
    return friends ??
        const FriendListResult(
          items: [FriendSummary(uid: '2', username: 'buddy')],
        );
  }

  @override
  Future<DarkRoomPage> getDarkRoom({String? cursor}) async {
    if (cursor != null) return DarkRoomPage.empty;
    return const DarkRoomPage(
      items: [
        DarkRoomEntry(
          cid: '1',
          uid: '223056',
          username: 'example_user',
          operatorId: '245',
          operatorName: '管理员',
          action: '禁止发言',
          reason: '测试',
          datelineRaw: '2026-7-14',
          groupExpiryRaw: '永不过期',
        ),
      ],
      nextCursor: '2',
      hasMore: true,
    );
  }
}
