import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s1er/models/app_exceptions.dart';
import 'package:s1er/services/app_update_downloader.dart';

Uint8List _zipBytes({int extra = 4}) {
  return Uint8List.fromList([
    0x50,
    0x4B,
    0x03,
    0x04,
    ...List<int>.filled(extra, 1),
  ]);
}

void main() {
  late Directory tempRoot;

  setUp(() async {
    tempRoot = await Directory.systemTemp.createTemp('s1er_apk_dl_');
  });

  tearDown(() async {
    if (await tempRoot.exists()) {
      await tempRoot.delete(recursive: true);
    }
  });

  group('AppUpdateDownloader', () {
    test('downloads allowed URL into updates dir', () async {
      final bytes = _zipBytes();
      final dio = Dio()..httpClientAdapter = _BytesAdapter(bytes);
      final downloader = AppUpdateDownloader(
        dio: dio,
        temporaryDirectory: () async => tempRoot,
      );

      final result = await downloader.downloadApk(
        urls: const [
          'https://github.com/Shirolin/s1er/releases/download/v1/app.apk',
        ],
        versionLabel: '1.0.0',
      );

      expect(result.filePath, endsWith('s1er-1.0.0.apk'));
      expect(File(result.filePath).existsSync(), isTrue);
      expect(File(result.filePath).lengthSync(), bytes.length);
    });

    test('skips disallowed host and fails when none left', () async {
      final downloader = AppUpdateDownloader(
        dio: Dio(),
        temporaryDirectory: () async => tempRoot,
      );
      expect(
        () => downloader.downloadApk(
          urls: const ['https://evil.example/app.apk'],
          versionLabel: '1.0.0',
        ),
        throwsA(
          isA<UpdateCheckException>().having(
            (e) => e.message,
            'message',
            '没有可用的下载地址',
          ),
        ),
      );
    });

    test('tries next URL after first failure', () async {
      final bytes = _zipBytes(extra: 2);
      final dio = Dio()
        ..httpClientAdapter = _UrlSensitiveAdapter(
          failPathContains: 'missing.apk',
          bytes: bytes,
        );
      final downloader = AppUpdateDownloader(
        dio: dio,
        temporaryDirectory: () async => tempRoot,
      );

      final result = await downloader.downloadApk(
        urls: const [
          'https://github.com/Shirolin/s1er/releases/download/v1/missing.apk',
          'https://github.com/Shirolin/s1er/releases/download/v1/ok.apk',
        ],
        versionLabel: '1.0.0',
      );
      expect(result.sourceUrl, contains('ok.apk'));
      expect(File(result.filePath).lengthSync(), bytes.length);
    });

    test('rejects empty downloaded file', () async {
      final dio = Dio()..httpClientAdapter = _BytesAdapter(Uint8List(0));
      final downloader = AppUpdateDownloader(
        dio: dio,
        temporaryDirectory: () async => tempRoot,
      );
      expect(
        () => downloader.downloadApk(
          urls: const [
            'https://github.com/Shirolin/s1er/releases/download/v1/app.apk',
          ],
          versionLabel: '1.0.0',
        ),
        throwsA(
          isA<UpdateCheckException>().having(
            (e) => e.message,
            'message',
            '下载文件为空',
          ),
        ),
      );
    });

    test('rejects HTML payload that is not an APK', () async {
      final html = Uint8List.fromList(
        utf8.encode('<!DOCTYPE html><html><body>not apk</body></html>'),
      );
      final dio = Dio()..httpClientAdapter = _BytesAdapter(html);
      final downloader = AppUpdateDownloader(
        dio: dio,
        temporaryDirectory: () async => tempRoot,
      );
      expect(
        () => downloader.downloadApk(
          urls: const [
            'https://github.com/Shirolin/s1er/releases/download/v1/app.apk',
          ],
          versionLabel: '1.0.0',
        ),
        throwsA(
          isA<UpdateCheckException>().having(
            (e) => e.message,
            'message',
            '下载文件无效',
          ),
        ),
      );
    });

    test(
      'completes when Content-Length is reached even if the stream never closes',
      () async {
        final bytes = _zipBytes(extra: 16);
        final adapter = _HangingBodyAdapter(bytes);
        addTearDown(() => adapter.close());
        final dio = Dio()..httpClientAdapter = adapter;
        final downloader = AppUpdateDownloader(
          dio: dio,
          temporaryDirectory: () async => tempRoot,
        );

        final result = await downloader.downloadApk(
          urls: const [
            'https://github.com/Shirolin/s1er/releases/download/v1/app.apk',
          ],
          versionLabel: '1.0.0',
        );
        expect(File(result.filePath).lengthSync(), bytes.length);
      },
      timeout: const Timeout(Duration(seconds: 5)),
    );

    test('salvages a complete APK if the stream errors after the last byte',
        () async {
      final bytes = _zipBytes(extra: 8);
      final dio = Dio()
        ..httpClientAdapter = _ErrorAfterBytesAdapter(
          bytes: bytes,
        );
      final downloader = AppUpdateDownloader(
        dio: dio,
        temporaryDirectory: () async => tempRoot,
      );

      final result = await downloader.downloadApk(
        urls: const [
          'https://github.com/Shirolin/s1er/releases/download/v1/app.apk',
        ],
        versionLabel: '1.0.0',
      );
      expect(File(result.filePath).lengthSync(), bytes.length);
    });

    test('sends GitHub-friendly APK request headers', () async {
      RequestOptions? seen;
      final bytes = _zipBytes();
      final dio = Dio()
        ..httpClientAdapter = _CapturingAdapter(
          bytes: bytes,
          onFetch: (options) => seen = options,
        );
      final downloader = AppUpdateDownloader(
        dio: dio,
        temporaryDirectory: () async => tempRoot,
      );

      await downloader.downloadApk(
        urls: const [
          'https://github.com/Shirolin/s1er/releases/download/v1/app.apk',
        ],
        versionLabel: '1.0.0',
      );

      expect(seen, isNotNull);
      expect(
        seen!.headers[HttpHeaders.acceptHeader],
        'application/octet-stream',
      );
      expect(
        seen!.headers[HttpHeaders.acceptEncodingHeader],
        'identity',
      );
      expect(
        seen!.headers[HttpHeaders.connectionHeader],
        'close',
      );
    });

    test('downloads zip extension for Windows portable packages', () async {
      final bytes = _zipBytes();
      final dio = Dio()..httpClientAdapter = _BytesAdapter(bytes);
      final downloader = AppUpdateDownloader(
        dio: dio,
        temporaryDirectory: () async => tempRoot,
      );

      final result = await downloader.downloadApk(
        urls: const [
          'https://github.com/Shirolin/s1er/releases/download/v1/app.zip',
        ],
        versionLabel: '1.0.0',
        extension: 'zip',
      );
      expect(result.filePath, endsWith('s1er-1.0.0.zip'));
      expect(File(result.filePath).lengthSync(), bytes.length);
    });
  });
}

class _BytesAdapter implements HttpClientAdapter {
  _BytesAdapter(this.bytes);

  final Uint8List bytes;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromBytes(
      bytes,
      200,
      headers: {
        Headers.contentLengthHeader: [bytes.length.toString()],
      },
    );
  }
}

class _UrlSensitiveAdapter implements HttpClientAdapter {
  _UrlSensitiveAdapter({
    required this.failPathContains,
    required this.bytes,
  });

  final String failPathContains;
  final Uint8List bytes;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.uri.path.contains(failPathContains)) {
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.badResponse,
        response: Response(requestOptions: options, statusCode: 404),
      );
    }
    return ResponseBody.fromBytes(
      bytes,
      200,
      headers: {
        Headers.contentLengthHeader: [bytes.length.toString()],
      },
    );
  }
}

class _HangingBodyAdapter implements HttpClientAdapter {
  _HangingBodyAdapter(this.bytes);

  final Uint8List bytes;
  StreamController<Uint8List>? _controller;

  @override
  void close({bool force = false}) {
    _controller?.close();
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final controller = StreamController<Uint8List>();
    _controller = controller;
    scheduleMicrotask(() {
      if (!controller.isClosed) controller.add(bytes);
    });
    return ResponseBody(
      controller.stream,
      200,
      headers: {
        Headers.contentLengthHeader: [bytes.length.toString()],
      },
    );
  }
}

class _ErrorAfterBytesAdapter implements HttpClientAdapter {
  _ErrorAfterBytesAdapter({required this.bytes});

  final Uint8List bytes;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final controller = StreamController<Uint8List>();
    scheduleMicrotask(() {
      if (controller.isClosed) return;
      controller.add(bytes);
      controller.addError(
        DioException(
          requestOptions: options,
          type: DioExceptionType.receiveTimeout,
        ),
      );
    });
    return ResponseBody(
      controller.stream,
      200,
      headers: const {},
    );
  }
}

class _CapturingAdapter implements HttpClientAdapter {
  _CapturingAdapter({
    required this.bytes,
    required this.onFetch,
  });

  final Uint8List bytes;
  final void Function(RequestOptions options) onFetch;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    onFetch(options);
    return ResponseBody.fromBytes(
      bytes,
      200,
      headers: {
        Headers.contentLengthHeader: [bytes.length.toString()],
      },
    );
  }
}
