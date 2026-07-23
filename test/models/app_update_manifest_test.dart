import 'package:flutter_test/flutter_test.dart';
import 'package:s1er/models/app_update_manifest.dart';

void main() {
  group('AppUpdateManifest.fromJson', () {
    test('parses full payload', () {
      final m = AppUpdateManifest.fromJson({
        'latest': '1.2.0',
        'minSupported': '1.0.0',
        'notes': '修复若干问题',
        'publishedAt': '2026-07-17',
        'channels': {
          'github': 'https://github.com/Shirolin/s1er/releases/latest',
          'androidApk': 'https://example.com/app.apk',
          'androidApks': {
            'arm64-v8a': 'https://example.com/arm64.apk',
            'armeabi-v7a': 'https://example.com/v7a.apk',
            'x86_64': 'https://example.com/x64.apk',
          },
          'androidNetdisk': 'https://pan.baidu.com/s/xxxx',
          'netdiskHint': '提取码：abcd',
          'windows': null,
          'play': 'https://play.google.com/store/apps/details?id=x',
        },
      });
      expect(m.latest, '1.2.0');
      expect(m.minSupported, '1.0.0');
      expect(m.notes, '修复若干问题');
      expect(m.channels.androidApk, 'https://example.com/app.apk');
      expect(m.channels.androidApks, {
        'arm64-v8a': 'https://example.com/arm64.apk',
        'armeabi-v7a': 'https://example.com/v7a.apk',
        'x86_64': 'https://example.com/x64.apk',
      });
      expect(m.channels.androidNetdisk, 'https://pan.baidu.com/s/xxxx');
      expect(m.channels.netdiskHint, '提取码：abcd');
      expect(m.channels.windows, isNull);
      expect(m.channels.play, contains('play.google.com'));
    });

    test('defaults minSupported and github when missing', () {
      final m = AppUpdateManifest.fromJson({'latest': '2.0.0'});
      expect(m.minSupported, '2.0.0');
      expect(m.notes, isEmpty);
      expect(m.channels.github, contains('github.com/Shirolin/s1er'));
      expect(m.channels.androidApks, isNull);
    });

    test('ignores empty androidApks map', () {
      final m = AppUpdateManifest.fromJson({
        'latest': '1.0.0',
        'channels': {
          'androidApks': {'arm64-v8a': '  '},
        },
      });
      expect(m.channels.androidApks, isNull);
    });

    test('throws when latest missing', () {
      expect(
        () => AppUpdateManifest.fromJson({}),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
