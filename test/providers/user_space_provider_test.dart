import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s1er/providers/user_space_provider.dart';
import 'package:s1er/services/http_client.dart';

void main() {
  group('user space list providers', () {
    late _UserSpaceAdapter adapter;
    late ProviderContainer container;

    setUp(() {
      adapter = _UserSpaceAdapter();
      final dio = Dio()..httpClientAdapter = adapter;
      late ProviderContainer c;
      c = ProviderContainer(
        overrides: [
          httpClientProvider.overrideWith(
            (ref) => S1HttpClient.test(c, dio),
          ),
        ],
      );
      container = c;
    });

    tearDown(() {
      container.dispose();
    });

    test('threads provider loads only thread requests', () async {
      final sub =
          container.listen(userSpaceThreadsProvider(('42', false)), (_, __) {});
      addTearDown(sub.close);

      await container.read(userSpaceThreadsProvider(('42', false)).future);

      expect(adapter.requestTypes, ['thread']);
    });

    test('replies provider loads independently without threads', () async {
      final sub =
          container.listen(userSpaceRepliesProvider(('42', false)), (_, __) {});
      addTearDown(sub.close);

      await container.read(userSpaceRepliesProvider(('42', false)).future);

      expect(adapter.requestTypes, ['reply']);
      expect(
        container
            .read(userSpaceRepliesProvider(('42', false)))
            .asData!
            .value
            .page,
        1,
      );
    });

    test('self threads use mythread module', () async {
      final sub =
          container.listen(userSpaceThreadsProvider(('42', true)), (_, __) {});
      addTearDown(sub.close);

      await container.read(userSpaceThreadsProvider(('42', true)).future);

      expect(adapter.requestTypes, ['mythread']);
    });

    test('listening both providers fetches thread and reply', () async {
      final threadSub =
          container.listen(userSpaceThreadsProvider(('42', false)), (_, __) {});
      final replySub =
          container.listen(userSpaceRepliesProvider(('42', false)), (_, __) {});
      addTearDown(threadSub.close);
      addTearDown(replySub.close);

      await Future.wait([
        container.read(userSpaceThreadsProvider(('42', false)).future),
        container.read(userSpaceRepliesProvider(('42', false)).future),
      ]);

      expect(adapter.requestTypes, containsAll(['thread', 'reply']));
      expect(adapter.requestTypes, hasLength(2));
    });

    test('refresh reloads only the same provider', () async {
      final threadSub =
          container.listen(userSpaceThreadsProvider(('42', false)), (_, __) {});
      final replySub =
          container.listen(userSpaceRepliesProvider(('42', false)), (_, __) {});
      addTearDown(threadSub.close);
      addTearDown(replySub.close);

      await Future.wait([
        container.read(userSpaceThreadsProvider(('42', false)).future),
        container.read(userSpaceRepliesProvider(('42', false)).future),
      ]);
      adapter.requestTypes.clear();

      await container
          .read(userSpaceThreadsProvider(('42', false)).notifier)
          .refresh();

      expect(adapter.requestTypes, ['thread']);
    });

    test('goToPage only hits the same list type', () async {
      final sub =
          container.listen(userSpaceRepliesProvider(('42', false)), (_, __) {});
      addTearDown(sub.close);

      await container.read(userSpaceRepliesProvider(('42', false)).future);
      adapter.requestTypes.clear();

      await container
          .read(userSpaceRepliesProvider(('42', false)).notifier)
          .goToPage(2);

      expect(adapter.requestTypes, ['reply']);
      expect(
        container
            .read(userSpaceRepliesProvider(('42', false)))
            .asData!
            .value
            .page,
        2,
      );
    });
  });
}

class _UserSpaceAdapter implements HttpClientAdapter {
  final requestTypes = <String>[];

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final uri = options.uri.toString();
    if (uri.contains('module=mythread')) {
      requestTypes.add('mythread');
      return _jsonBody();
    }
    if (uri.contains('type=reply')) {
      requestTypes.add('reply');
      return ResponseBody.fromString(_replyHtml, 200);
    }
    if (uri.contains('type=thread')) {
      requestTypes.add('thread');
      return ResponseBody.fromString(_threadHtml, 200);
    }
    return ResponseBody.fromString('{}', 200);
  }

  ResponseBody _jsonBody() {
    return ResponseBody.fromString(
      jsonEncode({
        'Variables': {
          'data': [],
          'total': '0',
        },
      }),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  static const _threadHtml = '''
<html><body>
<ul id="threadlist">
</ul>
</body></html>
''';

  static const _replyHtml = '''
<html><body>
<ul id="replylist">
</ul>
</body></html>
''';
}
