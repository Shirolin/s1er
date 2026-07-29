import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s1er/models/quote_info.dart';
import 'package:s1er/services/api_service.dart';
import 'package:s1er/services/formhash_service.dart';
import 'package:s1er/services/http_client.dart';

void main() {
  group('QuoteInfo.tryParse', () {
    test('parses noticeauthor and noticetrimstr', () {
      const xml = '''
<root>
<input type="hidden" name="noticeauthor" value="d755encoded" />
<input type="hidden" name="noticetrimstr" value="[post][url=forum.php?mod=redirect&amp;goto=findpost&amp;pid=1&amp;ptid=2]a[/url][/post]" />
</root>
''';
      final info = QuoteInfo.tryParse(xml);
      expect(info?.noticeAuthor, 'd755encoded');
      expect(info?.noticeTrimStr, contains('goto=findpost'));
      expect(info?.noticeTrimStr, contains('&ptid=2'));
      expect(info?.noticeTrimStr, isNot(contains('&amp;')));
    });

    test('returns null when fields missing', () {
      expect(QuoteInfo.tryParse('<root></root>'), isNull);
    });
  });

  group('QuoteInfo.submitNoticeTrimStr', () {
    test('rewrites [post] wrapper to [quote], keeps findpost', () {
      const info = QuoteInfo(
        noticeAuthor: 'd755encoded',
        noticeTrimStr:
            '[post][url=forum.php?mod=redirect&goto=findpost&pid=1&ptid=2]a[/url][/post]',
      );
      expect(
        info.submitNoticeTrimStr,
        '[quote][url=forum.php?mod=redirect&goto=findpost&pid=1&ptid=2]a[/url][/quote]',
      );
      expect(info.submitNoticeTrimStr, isNot(contains('[post]')));
      expect(info.submitNoticeTrimStr, contains('goto=findpost'));
    });

    test('leaves already-[quote] trim unchanged', () {
      const trim =
          '[quote][url=forum.php?mod=redirect&goto=findpost&pid=1&ptid=2]'
          'bob[/url] body[/quote]';
      const info = QuoteInfo(noticeAuthor: 'x', noticeTrimStr: trim);
      expect(info.submitNoticeTrimStr, trim);
    });

    test('rewrites case-insensitively', () {
      const info = QuoteInfo(
        noticeAuthor: 'x',
        noticeTrimStr: '[POST]inner[/POST]',
      );
      expect(info.submitNoticeTrimStr, '[quote]inner[/quote]');
    });
  });

  group('ApiService.parseSendReplyResponse', () {
    test('success with Variables pid/tid', () {
      final result = ApiService.parseSendReplyResponse({
        'Message': {
          'messageval': 'post_reply_succeed',
          'messagestr': '回复发布成功',
        },
        'Variables': {'pid': '99', 'tid': '88'},
      });
      expect(result.isSuccess, isTrue);
      expect(result.pid, '99');
      expect(result.tid, '88');
    });

    test('maps mobile:post_reply_toofast', () {
      final result = ApiService.parseSendReplyResponse({
        'Message': {
          'messageval': 'mobile:post_reply_toofast',
          'messagestr': 'post_reply_toofast',
        },
      });
      expect(result.isSuccess, isFalse);
      expect(result.error, contains('间隔过短'));
    });

    test('falls back to XML parser', () {
      const xml =
          "<root><![CDATA[<script>succeedhandle_reply('r', 'ok', {fid:'4',tid:'456',pid:'123'});</script>]]></root>";
      final result = ApiService.parseSendReplyResponse(xml);
      expect(result.isSuccess, isTrue);
      expect(result.pid, '123');
    });
  });

  group('ApiService.parseReplyResponse with attach flow', () {
    test('parses web succeedhandle after attachnew submit', () {
      const xml =
          "<root><![CDATA[<script>succeedhandle_postform('r', 'ok', {fid:'4',tid:'456',pid:'210'});</script>]]></root>";
      final result = ApiService.parseReplyResponse(xml);
      expect(result.isSuccess, isTrue);
      expect(result.pid, '210');
      expect(result.tid, '456');
    });

    test('parses empty succeedhandle_ after attachnew submit', () {
      const xml =
          "<root><![CDATA[<script>succeedhandle_('forum.php?mod=viewthread&tid=1&pid=2', 'ok', {'fid':'4','tid':'1','pid':'2'});</script>]]></root>";
      final result = ApiService.parseReplyResponse(xml);
      expect(result.isSuccess, isTrue);
      expect(result.pid, '2');
      expect(result.tid, '1');
    });

    test('parses two-arg succeedhandle_ without meta object', () {
      const xml =
          "<root><![CDATA[<script>succeedhandle_('forum.php?mod=viewthread&tid=9&pid=8', '回复发布成功');</script>]]></root>";
      final result = ApiService.parseReplyResponse(xml);
      expect(result.isSuccess, isTrue);
      expect(result.pid, '8');
      expect(result.tid, '9');
    });

    test('success when only messagestr contains Chinese success text', () {
      final result = ApiService.parseSendReplyResponse({
        'Message': {
          'messageval': '',
          'messagestr': '非常感谢，回复发布成功，现在将转入主题页',
        },
        'Variables': {'pid': '55', 'tid': '66'},
      });
      expect(result.isSuccess, isTrue);
      expect(result.pid, '55');
      expect(result.tid, '66');
    });
  });

  group('ApiService.sendReply contract', () {
    late ProviderContainer container;
    late _SendReplyRecordingAdapter adapter;
    late ApiService api;

    setUp(() {
      container = ProviderContainer();
      adapter = _SendReplyRecordingAdapter();
      final dio = Dio()..httpClientAdapter = adapter;
      api = ApiService(S1HttpClient.test(container, dio));
    });

    tearDown(() {
      container.dispose();
    });

    test('mobile path posts to sendreply with plain response type', () async {
      final result = await api.sendReply(
        tid: '100',
        fid: '4',
        message: '纯文本回复',
      );

      expect(result.isSuccess, isTrue);
      expect(adapter.lastOptions?.responseType, ResponseType.plain);
      expect(adapter.lastOptions?.uri.toString(), contains('sendreply'));
      expect(adapter.lastOptions?.data, isA<Map>());
      final data = adapter.lastOptions!.data as Map;
      expect(data['tid'], '100');
      expect(data['message'], '纯文本回复');
    });

    test('attach path posts to web reply with plain response type', () async {
      container.read(formhashProvider.notifier).update('abc12345');

      final result = await api.sendReply(
        tid: '100',
        fid: '4',
        message: '附图[attachimg]123[/attachimg]',
      );

      expect(result.isSuccess, isTrue);
      expect(adapter.lastOptions?.responseType, ResponseType.plain);
      expect(
        adapter.lastOptions?.uri.toString(),
        contains('mod=post&action=reply'),
      );
      final data = adapter.lastOptions!.data as Map;
      expect(data['attachnew[123][description]'], '');
      expect(data['attachnew[123][readperm]'], '');
    });

    test('transport timeout maps to uncertain', () async {
      container.read(formhashProvider.notifier).update('abc12345');
      adapter.throwOnPost = DioException(
        requestOptions: RequestOptions(path: '/'),
        type: DioExceptionType.receiveTimeout,
      );

      final result = await api.sendReply(
        tid: '100',
        fid: '4',
        message: '纯文本回复',
      );

      expect(result.isUncertain, isTrue);
      expect(result.isSuccess, isFalse);
      expect(result.message, contains('状态不确定'));
    });

    test('rejected when server returns explicit error', () async {
      adapter.forceReject = true;

      final result = await api.sendReply(
        tid: '100',
        fid: '4',
        message: '纯文本回复',
      );

      expect(result.isSuccess, isFalse);
      expect(result.message, '内容过长');
    });
  });
}

class _SendReplyRecordingAdapter implements HttpClientAdapter {
  RequestOptions? lastOptions;
  DioException? throwOnFetch;
  DioException? throwOnPost;
  bool forceReject = false;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastOptions = options;
    if (throwOnFetch != null) throw throwOnFetch!;
    if (options.method != 'GET' && throwOnPost != null) throw throwOnPost!;

    if (options.method == 'GET') {
      return ResponseBody.fromString(
        jsonEncode({
          'Variables': {'formhash': 'abc12345'},
        }),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }

    final path = options.uri.toString();
    if (path.contains('mod=post&action=reply')) {
      if (forceReject) {
        return ResponseBody.fromString(
          "<script>errorhandle_reply('内容过长', '');</script>",
          200,
        );
      }
      return ResponseBody.fromString(
        "<script>succeedhandle_('forum.php?mod=viewthread&tid=100&pid=9', 'ok', {'tid':'100','pid':'9'});</script>",
        200,
      );
    }

    if (forceReject) {
      return ResponseBody.fromString(
        jsonEncode({
          'Message': {
            'messageval': 'post_reply_invalid',
            'messagestr': '内容过长',
          },
        }),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }

    return ResponseBody.fromString(
      jsonEncode({
        'Message': {'messageval': 'post_reply_succeed'},
        'Variables': {'pid': '7', 'tid': '100'},
      }),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}
