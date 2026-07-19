import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s1er/models/app_exceptions.dart';
import 'package:s1er/services/app_update_downloader.dart';

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
      final dio = Dio()
        ..httpClientAdapter = _BytesAdapter(Uint8List.fromList([1, 2, 3, 4]));
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
      expect(File(result.filePath).lengthSync(), 4);
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
      final dio = Dio()
        ..httpClientAdapter = _UrlSensitiveAdapter(
          failPathContains: 'missing.apk',
          bytes: Uint8List.fromList([9, 9]),
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
      expect(File(result.filePath).lengthSync(), 2);
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
