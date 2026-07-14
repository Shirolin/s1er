import 'dart:convert';
import 'dart:math';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:cryptography/cryptography.dart';
import 'package:cryptography/dart.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// 使用 AES-256-GCM 加密 [FileStorage] 落盘内容，密钥存于安全存储。
class EncryptedCookieStorage {
  EncryptedCookieStorage._();

  static const _keyStorageId = 's1_cookie_encryption_key';
  static const _secureStorage = FlutterSecureStorage();
  static final DartAesGcm _algorithm = DartAesGcm();

  /// 创建带加密读写的 [FileStorage]。
  static Future<FileStorage> create(String dir) async {
    final secretKeyData = await _loadOrCreateKeyData();
    return buildEncryptedStorage(dir, secretKeyData);
  }

  /// 测试用：使用固定密钥构建加密存储。
  @visibleForTesting
  static FileStorage buildEncryptedStorage(
      String dir, SecretKeyData secretKeyData,) {
    final storage = FileStorage(dir);

    storage.readPreHandler = (Uint8List bytes) {
      if (bytes.isEmpty) return null;
      try {
        final box = SecretBox.fromConcatenation(
          bytes,
          nonceLength: _algorithm.nonceLength,
          macLength: _algorithm.macAlgorithm.macLength,
        );
        final decrypted =
            _algorithm.decryptSync(box, secretKeyData: secretKeyData);
        return utf8.decode(decrypted);
      } catch (_) {
        return null;
      }
    };

    storage.writePreHandler = (String value) {
      final nonce = _algorithm.newNonce();
      final box = _algorithm.encryptSync(
        utf8.encode(value),
        secretKeyData: secretKeyData,
        nonce: nonce,
      );
      return box.concatenation();
    };

    return storage;
  }

  static Future<SecretKeyData> _loadOrCreateKeyData() async {
    var encoded = await _secureStorage.read(key: _keyStorageId);
    if (encoded == null || encoded.isEmpty) {
      final random = Random.secure();
      final keyBytes = List<int>.generate(32, (_) => random.nextInt(256));
      encoded = base64Url.encode(keyBytes);
      await _secureStorage.write(key: _keyStorageId, value: encoded);
      return SecretKeyData(keyBytes);
    }
    return SecretKeyData(base64Url.decode(encoded));
  }
}
