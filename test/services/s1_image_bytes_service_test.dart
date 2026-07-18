import 'package:dio/dio.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s1er/services/http_client.dart';
import 'package:s1er/services/s1_image_bytes_service.dart';
import 'package:s1er/services/s1_image_cache.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    S1ImageCache.debugSetManager(_EmptyCacheManager());
  });

  tearDown(() {
    S1ImageCache.debugSetManager(null);
  });

  test('fetchBytes returns null on 404 without throwing', () async {
    final dio = Dio()..httpClientAdapter = _StatusAdapter(404);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final client = S1HttpClient.test(container, dio);
    final service = S1ImageBytesService(client);

    final bytes = await service.fetchBytes(
      'https://avatar.stage1st.com/000/57/50/24_avatar_small.jpg',
    );
    expect(bytes, isNull);
  });
}

class _EmptyCacheManager implements CacheManager {
  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #getFileFromCache) {
      return Future<FileInfo?>.value(null);
    }
    return null;
  }
}

class _StatusAdapter implements HttpClientAdapter {
  _StatusAdapter(this.statusCode);

  final int statusCode;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString('', statusCode);
  }
}
