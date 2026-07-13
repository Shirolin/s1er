import 'dart:typed_data';

import 'package:dio/dio.dart';

import 'http_client.dart';
import 's1_image_cache.dart';
import 'talker.dart';

class S1ImageBytesService {
  S1ImageBytesService(this._httpClient);

  final S1HttpClient _httpClient;

  Future<Uint8List?> fetchBytes(String url) async {
    try {
      final disk = await S1ImageCache.getBytes(url);
      if (disk != null) return disk;

      final response = await _httpClient.get(
        url,
        options: Options(responseType: ResponseType.bytes),
      );
      final raw = response.data;
      final bytes = switch (raw) {
        Uint8List value => value,
        List<int> value => Uint8List.fromList(value),
        _ => null,
      };
      if (bytes == null) return null;

      await S1ImageCache.putBytes(url, bytes);
      return bytes;
    } catch (e, st) {
      talker.handle(e, st, 'Fetch image bytes failed: $url');
      return null;
    }
  }
}
