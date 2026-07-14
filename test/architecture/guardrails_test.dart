import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  final repoRoot = Directory.current.path;

  String read(String relativePath) =>
      File(p.join(repoRoot, relativePath)).readAsStringSync();

  Iterable<File> dartFiles(String relativeDir) sync* {
    final dir = Directory(p.join(repoRoot, relativeDir));
    if (!dir.existsSync()) return;
    yield* dir
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'));
  }

  test('screens and widgets do not bypass provider layer for HTTP access', () {
    final blockedPatterns = [
      'httpClientProvider',
      'ApiService(',
    ];

    for (final file in [
      ...dartFiles('lib/screens'),
      ...dartFiles('lib/widgets'),
    ]) {
      final source = file.readAsStringSync();
      for (final pattern in blockedPatterns) {
        expect(
          source.contains(pattern),
          isFalse,
          reason: '${p.relative(file.path, from: repoRoot)} contains $pattern',
        );
      }
    }
  });

  test('screens and widgets do not directly import services', () {
    for (final file in [
      ...dartFiles('lib/screens'),
      ...dartFiles('lib/widgets'),
    ]) {
      final source = file.readAsStringSync();
      expect(source, isNot(contains("import '../services/")));
      expect(source, isNot(contains('import "../services/')));
      expect(source, isNot(contains("import '../../services/")));
      expect(source, isNot(contains('import "../../services/')));
    }
  });

  test('dynamic color implementation is fully removed from app sources', () {
    final blockedPatterns = [
      'dynamic_color',
      'DynamicColorBuilder',
      'useDynamicColor',
      'simulateDynamic',
      'dynamicColorAvailableProvider',
      'isDynamic:',
    ];

    for (final file in dartFiles('lib')) {
      final source = file.readAsStringSync();
      for (final pattern in blockedPatterns) {
        expect(
          source.contains(pattern),
          isFalse,
          reason:
              '${p.relative(file.path, from: repoRoot)} still contains $pattern',
        );
      }
    }
  });

  test('send timeout uses EnvConfig and selected files avoid naked catch', () {
    final envConfig = read('lib/config/env_config.dart');
    final httpClient = read('lib/services/http_client.dart');

    expect(envConfig.contains('SEND_TIMEOUT'), isTrue);
    expect(httpClient.contains('sendTimeout:'), isTrue);
    expect(httpClient.contains('EnvConfig.sendTimeoutSeconds'), isTrue);

    final auditedFiles = [
      'lib/providers/auth_provider.dart',
      'lib/screens/image_viewer_screen.dart',
      'lib/services/app_local_data.dart',
      'lib/services/backup/s1_backup_service.dart',
      'lib/services/settings_store.dart',
      'lib/theme/app_theme.dart',
      'lib/widgets/settings/theme_settings_section.dart',
    ];

    for (final path in auditedFiles) {
      final source = read(path);
      expect(
        source.contains('catch (_)'),
        isFalse,
        reason: '$path still contains catch (_)',
      );
    }
  });

  test('current diff does not add naked catches', () {
    final result = Process.runSync(
      'git',
      ['diff', '--unified=0', '--', 'lib'],
    );
    expect(result.exitCode, 0);
    final addedLines = result.stdout
        .toString()
        .split('\n')
        .where((line) => line.startsWith('+') && !line.startsWith('+++'));
    expect(
      addedLines.where((line) => line.contains(RegExp(r'catch\s*\(_\)'))),
      isEmpty,
    );
  });
}
