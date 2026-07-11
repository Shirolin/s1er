import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('audit_m3.dart reports zero P0 on project lib/', () async {
    final result = await Process.run(
      'dart',
      ['run', 'scripts/audit_m3.dart', '--fail-on-error'],
      runInShell: true,
    );

    expect(
      result.exitCode,
      0,
      reason: 'P0 violations:\n${result.stdout}\n${result.stderr}',
    );
    expect(result.stdout.toString(), contains('Scanned: lib/ + test/'));
  });

  test('audit rules detect semantic Colors and bare fontSize', () {
    final colorsPattern = RegExp(r'Colors\.(?!transparent\b)\w+');
    final fontSizePattern = RegExp(r'fontSize:\s*\d');

    expect(colorsPattern.hasMatch('color: Colors.red'), isTrue);
    expect(colorsPattern.hasMatch('color: Colors.transparent'), isFalse);

    expect(fontSizePattern.hasMatch('fontSize: 14'), isTrue);
    expect(fontSizePattern.hasMatch('fontSize: radius * 0.8'), isFalse);
  });
}
