import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s1_app/providers/user_space_provider.dart';
import 'package:s1_app/services/http_client.dart';

void main() {
  group('UserSpaceNotifier', () {
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

    test('build loads only threads for other user space', () async {
      final sub = container.listen(userSpaceProvider(('42', false)), (_, __) {});
      addTearDown(sub.close);

      await container.read(userSpaceProvider(('42', false)).future);

      expect(adapter.requestTypes, ['thread']);
    });

    test('ensureRepliesLoaded fetches replies after initial build', () async {
      final sub = container.listen(userSpaceProvider(('42', false)), (_, __) {});
      addTearDown(sub.close);

      final notifier = container.read(userSpaceProvider(('42', false)).notifier);
      await container.read(userSpaceProvider(('42', false)).future);
      expect(adapter.requestTypes, ['thread']);

      await notifier.ensureRepliesLoaded();

      expect(adapter.requestTypes, ['thread', 'reply']);
      expect(
        container.read(userSpaceProvider(('42', false))).asData!.value.repliesLoaded,
        isTrue,
      );
    });

    test('refresh reloads only threads when replies not loaded', () async {
      final sub = container.listen(userSpaceProvider(('42', false)), (_, __) {});
      addTearDown(sub.close);

      final notifier = container.read(userSpaceProvider(('42', false)).notifier);
      await container.read(userSpaceProvider(('42', false)).future);
      adapter.requestTypes.clear();

      await notifier.refresh();

      expect(adapter.requestTypes, ['thread']);
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
