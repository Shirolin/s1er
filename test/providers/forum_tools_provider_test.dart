import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s1_app/models/app_exceptions.dart';
import 'package:s1_app/models/attendance_result.dart';
import 'package:s1_app/models/dark_room_entry.dart';
import 'package:s1_app/models/friend_summary.dart';
import 'package:s1_app/models/user.dart';
import 'package:s1_app/providers/auth_provider.dart';
import 'package:s1_app/providers/daily_attendance_provider.dart';
import 'package:s1_app/providers/dark_room_provider.dart';
import 'package:s1_app/providers/forum_tools_provider.dart';
import 'package:s1_app/providers/friend_list_provider.dart';
import 'package:s1_app/services/forum_tools_service.dart';
import 'package:s1_app/services/http_client.dart';

void main() {
  group('friendListProvider', () {
    test('loads friends for current user', () async {
      final service = _FakeForumToolsService();
      final container = ProviderContainer(
        overrides: [
          forumToolsServiceProvider.overrideWithValue(service),
          authStateProvider.overrideWith(
            () => _Auth(
              AuthState(
                isLoggedIn: true,
                username: 'me',
                user: User(uid: '9', username: 'me'),
              ),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      final sub = container.listen(friendListProvider, (_, __) {});
      addTearDown(sub.close);

      final result = await container.read(friendListProvider.future);
      expect(result.items.single.username, 'buddy');
      expect(service.friendCalls, ['9']);
    });

    test('requires login', () async {
      final container = ProviderContainer(
        overrides: [
          forumToolsServiceProvider.overrideWithValue(_FakeForumToolsService()),
          authStateProvider.overrideWith(() => _Auth(AuthState())),
        ],
      );
      addTearDown(container.dispose);
      final sub = container.listen(friendListProvider, (_, __) {});
      addTearDown(sub.close);

      await pumpEventQueue();
      final async = container.read(friendListProvider);
      expect(async.hasError, isTrue);
      expect(async.error, isA<LoginRequiredException>());
    });
  });

  group('dailyAttendanceProvider', () {
    test('ignores concurrent sign calls', () async {
      final service = _FakeForumToolsService(delaySign: true);
      final container = ProviderContainer(
        overrides: [forumToolsServiceProvider.overrideWithValue(service)],
      );
      addTearDown(container.dispose);
      final sub = container.listen(dailyAttendanceProvider, (_, __) {});
      addTearDown(sub.close);

      final notifier = container.read(dailyAttendanceProvider.notifier);
      final first = notifier.sign();
      final second = notifier.sign();
      await Future.wait([first, second]);
      expect(service.signCalls, 1);
      expect(
        container.read(dailyAttendanceProvider).result?.outcome,
        AttendanceOutcome.signedNow,
      );
    });
  });

  group('darkRoomProvider', () {
    test('refresh resets and loadMore appends', () async {
      final service = _FakeForumToolsService();
      final container = ProviderContainer(
        overrides: [forumToolsServiceProvider.overrideWithValue(service)],
      );
      addTearDown(container.dispose);
      final sub = container.listen(darkRoomProvider, (_, __) {});
      addTearDown(sub.close);

      final first = await container.read(darkRoomProvider.future);
      expect(first.items, hasLength(1));
      expect(first.hasMore, isTrue);

      await container.read(darkRoomProvider.notifier).loadMore();
      final more = container.read(darkRoomProvider).asData!.value;
      expect(more.items, hasLength(2));
      expect(more.hasMore, isFalse);

      await container.read(darkRoomProvider.notifier).refresh();
      final refreshed = await container.read(darkRoomProvider.future);
      expect(refreshed.items, hasLength(1));
      expect(service.darkRoomCursors.first, isNull);
    });

    test('keeps old data when loadMore fails', () async {
      final service = _FakeForumToolsService(failOnSecondPage: true);
      final container = ProviderContainer(
        overrides: [forumToolsServiceProvider.overrideWithValue(service)],
      );
      addTearDown(container.dispose);
      final sub = container.listen(darkRoomProvider, (_, __) {});
      addTearDown(sub.close);

      await container.read(darkRoomProvider.future);
      await container.read(darkRoomProvider.notifier).loadMore();
      final state = container.read(darkRoomProvider).asData!.value;
      expect(state.items, hasLength(1));
      expect(state.isLoadingMore, isFalse);
    });
  });
}

class _Auth extends AuthNotifier {
  _Auth(this.initial);
  final AuthState initial;

  @override
  AuthState build() => initial;
}

class _FakeForumToolsService extends ForumToolsService {
  _FakeForumToolsService({
    this.delaySign = false,
    this.failOnSecondPage = false,
  }) : super(S1HttpClient.test(ProviderContainer(), Dio()));

  final bool delaySign;
  final bool failOnSecondPage;
  final friendCalls = <String>[];
  final darkRoomCursors = <String?>[];
  var signCalls = 0;

  @override
  Future<FriendListResult> getFriendList({required String uid}) async {
    friendCalls.add(uid);
    return const FriendListResult(
      items: [FriendSummary(uid: '2', username: 'buddy')],
    );
  }

  @override
  Future<AttendanceResult> dailySign() async {
    signCalls += 1;
    if (delaySign) {
      await Future<void>.delayed(const Duration(milliseconds: 30));
    }
    return const AttendanceResult(
      outcome: AttendanceOutcome.signedNow,
      message: '签到成功',
    );
  }

  @override
  Future<DarkRoomPage> getDarkRoom({String? cursor}) async {
    darkRoomCursors.add(cursor);
    if (cursor == null) {
      return const DarkRoomPage(
        items: [
          DarkRoomEntry(
            cid: '1',
            uid: '10',
            username: 'u1',
            operatorId: '1',
            operatorName: 'op',
            action: '禁止发言',
            reason: 'r',
            datelineRaw: 't',
            groupExpiryRaw: 'e',
          ),
        ],
        nextCursor: 'next',
        hasMore: true,
      );
    }
    if (failOnSecondPage) {
      throw Exception('boom');
    }
    return const DarkRoomPage(
      items: [
        DarkRoomEntry(
          cid: '2',
          uid: '11',
          username: 'u2',
          operatorId: '1',
          operatorName: 'op',
          action: '禁止访问',
          reason: '',
          datelineRaw: 't2',
          groupExpiryRaw: '永不过期',
        ),
      ],
      nextCursor: 'end',
      hasMore: false,
    );
  }
}
