import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s1er/models/thread_list_query.dart';
import 'package:s1er/providers/settings_provider.dart';
import 'package:s1er/providers/thread_list_provider.dart';
import 'package:s1er/services/app_database.dart';
import 'package:s1er/services/app_local_data.dart';
import 'package:s1er/services/http_client.dart';

void main() {
  group('ThreadListNotifier', () {
    late _ThreadListAdapter adapter;
    late AppDatabase db;
    late AppLocalData local;
    late ProviderContainer container;

    setUp(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      adapter = _ThreadListAdapter();
      db = AppDatabase.forTesting(NativeDatabase.memory());
      local = AppLocalData(db);
      await local.load();
      final dio = Dio()..httpClientAdapter = adapter;
      late ProviderContainer c;
      c = ProviderContainer(
        overrides: [
          localDataProvider.overrideWithValue(local),
          httpClientProvider.overrideWith(
            (ref) => S1HttpClient.test(c, dio),
          ),
        ],
      );
      container = c;
    });

    tearDown(() async {
      container.dispose();
      await local.flushPendingWrites();
      await db.close();
    });

    test('setQuery reloads page 1 with new params', () async {
      final sub = container.listen(threadListProvider('6'), (_, __) {});
      addTearDown(sub.close);

      await container.read(threadListProvider('6').future);
      expect(adapter.lastUri?.queryParameters['page'], '1');
      adapter.requests.clear();

      await container.read(threadListProvider('6').notifier).goToPage(2);
      expect(adapter.lastUri?.queryParameters['page'], '2');
      adapter.requests.clear();

      await container.read(threadListProvider('6').notifier).setQuery(
            const ThreadListQuery(preset: ThreadListSortPreset.newest),
          );

      final state = container.read(threadListProvider('6')).asData!.value;
      expect(state.currentPage, 1);
      expect(state.query.preset, ThreadListSortPreset.newest);
      expect(adapter.lastUri?.queryParameters['filter'], 'author');
      expect(adapter.lastUri?.queryParameters['orderby'], 'dateline');
      expect(adapter.lastUri?.queryParameters['page'], '1');
    });

    test('selectType resets to page 1 and keeps query', () async {
      final sub = container.listen(threadListProvider('6'), (_, __) {});
      addTearDown(sub.close);

      await container.read(threadListProvider('6').future);
      await container.read(threadListProvider('6').notifier).setQuery(
            const ThreadListQuery(preset: ThreadListSortPreset.heat),
          );
      await container.read(threadListProvider('6').notifier).goToPage(2);
      adapter.requests.clear();

      await container.read(threadListProvider('6').notifier).selectType('8');

      final state = container.read(threadListProvider('6')).asData!.value;
      expect(state.currentPage, 1);
      expect(state.selectedTypeId, '8');
      expect(state.query.preset, ThreadListSortPreset.heat);
      expect(adapter.lastUri?.queryParameters['filter'], 'typeid');
      expect(adapter.lastUri?.queryParameters['typeid'], '8');
      expect(adapter.lastUri?.queryParameters['orderby'], 'heats');
    });

    test('setQuery rolls back on failure', () async {
      final sub = container.listen(threadListProvider('6'), (_, __) {});
      addTearDown(sub.close);

      await container.read(threadListProvider('6').future);
      adapter.failNext = true;

      await container.read(threadListProvider('6').notifier).setQuery(
            const ThreadListQuery(preset: ThreadListSortPreset.digest),
          );

      final state = container.read(threadListProvider('6')).asData!.value;
      expect(state.query, ThreadListQuery.defaults);
      expect(state.isLoading, isFalse);
      expect(state.errorMessage, isNotNull);
    });

    test('hides sticky threads when global setting is on', () async {
      container.read(settingsProvider.notifier).setHideStickyThreads(true);
      final sub = container.listen(threadListProvider('6'), (_, __) {});
      addTearDown(sub.close);

      await container.read(threadListProvider('6').future);

      final state = container.read(threadListProvider('6')).asData!.value;
      expect(
        state.threads.map((t) => t.subject),
        ['Thread 1'],
        reason: 'sticky thread should be filtered out',
      );
      expect(
        state.sourceThreads.map((t) => t.subject),
        ['Thread 1', 'Sticky 1'],
        reason: 'sourceThreads keeps raw server data',
      );
    });

    test('toggling hide sticky live-refilters current page', () async {
      final sub = container.listen(threadListProvider('6'), (_, __) {});
      addTearDown(sub.close);

      await container.read(threadListProvider('6').future);
      var state = container.read(threadListProvider('6')).asData!.value;
      expect(
        state.threads.map((t) => t.subject),
        ['Thread 1', 'Sticky 1'],
      );

      container.read(settingsProvider.notifier).setHideStickyThreads(true);

      state = container.read(threadListProvider('6')).asData!.value;
      expect(state.threads.map((t) => t.subject), ['Thread 1']);
      expect(state.sourceThreads, hasLength(2));
    });

    test('per-forum override can hide sticky even when global is off',
        () async {
      container.read(settingsProvider.notifier).toggleHideStickyForum('6');
      final sub = container.listen(threadListProvider('6'), (_, __) {});
      addTearDown(sub.close);

      await container.read(threadListProvider('6').future);

      final state = container.read(threadListProvider('6')).asData!.value;
      expect(state.threads.map((t) => t.subject), ['Thread 1']);
      expect(state.sourceThreads, hasLength(2));
    });
  });
}

class _ThreadListAdapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  bool failNext = false;

  Uri? get lastUri =>
      requests.isEmpty ? null : Uri.parse(requests.last.uri.toString());

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (failNext) {
      failNext = false;
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.badResponse,
        message: 'forced failure',
      );
    }

    final page = options.uri.queryParameters['page'] ?? '1';
    final body = jsonEncode({
      'Variables': {
        'forum': {'fid': '6', 'name': '动漫论坛', 'threads': '100'},
        'threadcount': '100',
        'tpp': '50',
        'forum_threadlist': [
          {
            'tid': 't$page',
            'subject': 'Thread $page',
            'author': 'user',
            'authorid': '1',
            'dbdateline': '1700000000',
            'views': '1',
            'replies': '0',
            'typeid': '8',
          },
          {
            'tid': 'sticky-$page',
            'subject': 'Sticky $page',
            'author': 'mod',
            'authorid': '2',
            'displayorder': '3',
            'dbdateline': '1700000000',
            'views': '1',
            'replies': '0',
            'typeid': '8',
          },
        ],
        'threadtypes': {
          'types': {'8': '动画'},
        },
      },
    });
    return ResponseBody.fromString(
      body,
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}
