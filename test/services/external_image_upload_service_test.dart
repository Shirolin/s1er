import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s1_app/config/env_config.dart';
import 'package:s1_app/services/external_image_upload_service.dart';

void main() {
  group('ExternalImageUploadService', () {
    test('resolveUploadUrl uses direct host off Web', () {
      final url = ExternalImageUploadService.resolveUploadUrl(
        filename: '鲈鱼千秋.png',
        isWeb: false,
      );
      expect(url, startsWith('https://p.sda1.dev/api/v1/upload_external_noform'));
      expect(url, contains(Uri.encodeQueryComponent('鲈鱼千秋.png')));
    });

    test('resolveUploadUrl uses local proxy on Web', () {
      final url = ExternalImageUploadService.resolveUploadUrl(
        filename: 'a.png',
        isWeb: true,
      );
      expect(
        url,
        'http://localhost:${EnvConfig.proxyPort}/ext-upload'
        '?filename=${Uri.encodeQueryComponent('a.png')}',
      );
    });

    test('parses success JSON and returns url', () async {
      final dio = Dio()
        ..httpClientAdapter = _UploadAdapter(
          responseBody: jsonEncode({
            'code': 'success',
            'data': {
              'url': 'https://p.sda1.dev/0/abc/x.jpg',
            },
          }),
        );
      final service = ExternalImageUploadService(dio: dio);

      final url = await service.upload(
        bytes: Uint8List.fromList([1, 2, 3]),
        filename: 'x.jpg',
      );

      expect(url, 'https://p.sda1.dev/0/abc/x.jpg');
    });

    test('throws on non-success code', () async {
      final dio = Dio()
        ..httpClientAdapter = _UploadAdapter(
          responseBody: jsonEncode({'code': 'error'}),
        );
      final service = ExternalImageUploadService(dio: dio);

      expect(
        () => service.upload(
          bytes: Uint8List.fromList([1]),
          filename: 'a.png',
        ),
        throwsA(isA<ExternalImageUploadException>()),
      );
    });

    test('rejects files larger than maxBytes', () async {
      final service = ExternalImageUploadService(dio: Dio());
      final huge = Uint8List(ExternalImageUploadService.maxBytes + 1);

      await expectLater(
        () => service.upload(bytes: huge, filename: 'huge.jpg'),
        throwsA(
          isA<ExternalImageUploadException>().having(
            (e) => e.message,
            'message',
            contains('图片过大'),
          ),
        ),
      );
    });

    test('maps Dio sendTimeout to timeout message', () async {
      final dio = Dio()
        ..httpClientAdapter = _FailingAdapter(
          DioException(
            requestOptions: RequestOptions(path: '/'),
            type: DioExceptionType.sendTimeout,
          ),
        );
      final service = ExternalImageUploadService(dio: dio);

      await expectLater(
        () => service.upload(
          bytes: Uint8List.fromList([1]),
          filename: 'a.png',
        ),
        throwsA(
          isA<ExternalImageUploadException>().having(
            (e) => e.message,
            'message',
            contains('超时'),
          ),
        ),
      );
    });
  });
}

class _FailingAdapter implements HttpClientAdapter {
  _FailingAdapter(this.error);

  final DioException error;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    throw error;
  }
}

class _UploadAdapter implements HttpClientAdapter {
  _UploadAdapter({required this.responseBody});

  final String responseBody;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    // Unit tests run as VM (not Web) → direct图床 URL
    expect(options.uri.host, 'p.sda1.dev');
    expect(options.uri.path, contains('upload_external_noform'));
    return ResponseBody.fromString(
      responseBody,
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}
