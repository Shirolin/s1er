import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s1_app/services/encrypted_cookie_storage.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('s1_cookie_test_');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('encrypted storage round-trips cookie data', () async {
    final keyData = SecretKeyData(List<int>.filled(32, 1));
    final storage =
        EncryptedCookieStorage.buildEncryptedStorage(tempDir.path, keyData);
    await storage.init(true, true);

    const payload = 'session_cookie_data';
    await storage.write('test_key', payload);

    final read = await storage.read('test_key');
    expect(read, payload);
  });
}
