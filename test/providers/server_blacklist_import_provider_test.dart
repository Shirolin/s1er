import 'dart:async';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s1er/models/blacklist_record.dart';
import 'package:s1er/models/server_blacklist.dart';
import 'package:s1er/models/user.dart';
import 'package:s1er/providers/auth_provider.dart';
import 'package:s1er/providers/blacklist_provider.dart';
import 'package:s1er/providers/forum_tools_provider.dart';
import 'package:s1er/providers/server_blacklist_import_provider.dart';
import 'package:s1er/providers/settings_provider.dart';
import 'package:s1er/services/app_database.dart';
import 'package:s1er/services/app_local_data.dart';
import 'package:s1er/services/forum_tools_service.dart';
import 'package:s1er/services/http_client.dart';

void main() {
  late AppDatabase db;
  late AppLocalData local;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    local = AppLocalData(db);
    await local.load();
  });

  tearDown(() async {
    await local.flushPendingWrites();
    await db.close();
  });

  ProviderContainer createContainer(_FakeForumToolsService service) {
    final container = ProviderContainer(
      overrides: [
        localDataProvider.overrideWithValue(local),
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
    return container;
  }

  test('预览跨页去重，应用时保留本地私信和备注', () async {
    final service = _FakeForumToolsService({
      1: const ServerBlacklistPage(
        page: 1,
        totalPages: 2,
        items: [
          ServerBlacklistUser(uid: '1', username: '新名字'),
          ServerBlacklistUser(uid: '2', username: '新增用户'),
        ],
      ),
      2: const ServerBlacklistPage(
        page: 2,
        totalPages: 2,
        items: [ServerBlacklistUser(uid: '1', username: '新名字')],
      ),
    });
    final container = createContainer(service);
    await container.read(blacklistBootstrapProvider.future);
    container.read(blacklistServiceProvider).upsert(
          uid: '1',
          username: '旧名字',
          reason: '保留备注',
          scope: [BlacklistRecord.scopePm],
          createdAt: 123,
        );

    final notifier = container.read(serverBlacklistImportProvider.notifier);
    final preview = await notifier.loadPreview();

    expect(preview.users.map((user) => user.uid), ['1', '2']);
    expect(preview.updated.map((user) => user.uid), ['1']);
    expect(preview.added.map((user) => user.uid), ['2']);

    final result = await notifier.apply(preview);
    final existing = container.read(blacklistServiceProvider).get('1')!;
    final added = container.read(blacklistServiceProvider).get('2')!;

    expect(result.added, 1);
    expect(result.updated, 1);
    expect(existing.username, '新名字');
    expect(existing.reason, '保留备注');
    expect(existing.createdAt, 123);
    expect(
      existing.scope,
      [
        BlacklistRecord.scopePm,
        BlacklistRecord.scopeThread,
        BlacklistRecord.scopePost,
      ],
    );
    expect(added.scope, BlacklistRecord.defaultScopes);
  });

  test('预览中途失败不写入本地数据', () async {
    final service = _FakeForumToolsService(
      {
        1: const ServerBlacklistPage(
          page: 1,
          totalPages: 2,
          items: [ServerBlacklistUser(uid: '2', username: '新增用户')],
        ),
      },
      failOnPage: 2,
    );
    final container = createContainer(service);

    await expectLater(
      container.read(serverBlacklistImportProvider.notifier).loadPreview(),
      throwsA(isA<Exception>()),
    );

    expect(container.read(blacklistServiceProvider).get('2'), isNull);
  });

  test('导入进行时拒绝并发预览', () async {
    final pending = Completer<ServerBlacklistPage>();
    final service = _FakeForumToolsService({}, pendingPage: pending);
    final container = createContainer(service);
    final notifier = container.read(serverBlacklistImportProvider.notifier);

    final first = notifier.loadPreview();
    expect(
      () => notifier.loadPreview(),
      throwsA(isA<StateError>()),
    );
    pending.complete(
      const ServerBlacklistPage(page: 1, totalPages: 1, items: []),
    );
    await first;
  });
}

class _Auth extends AuthNotifier {
  _Auth(this.initial);

  final AuthState initial;

  @override
  AuthState build() => initial;
}

class _FakeForumToolsService extends ForumToolsService {
  _FakeForumToolsService(
    this.pages, {
    this.failOnPage,
    this.pendingPage,
  }) : super(S1HttpClient.test(ProviderContainer(), Dio()));

  final Map<int, ServerBlacklistPage> pages;
  final int? failOnPage;
  final Completer<ServerBlacklistPage>? pendingPage;

  @override
  Future<ServerBlacklistPage> getServerBlacklistPage({
    required String uid,
    required int page,
  }) async {
    if (pendingPage != null) return pendingPage!.future;
    if (page == failOnPage) throw Exception('读取失败');
    return pages[page]!;
  }
}
