import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/http_client.dart';
import '../services/s1_image_bytes_service.dart';

final s1ImageBytesServiceProvider = Provider<S1ImageBytesService>((ref) {
  return S1ImageBytesService(ref.watch(httpClientProvider));
});

final imageBytesProvider =
    FutureProvider.autoDispose.family<Uint8List?, String>((ref, url) async {
  return ref.watch(s1ImageBytesServiceProvider).fetchBytes(url);
});
