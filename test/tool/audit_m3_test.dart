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

  test('opacity-raw-value rule detects raw opacity literals', () {
    final pattern = RegExp(r'Opacity\(opacity:.*\b0\.\d+');

    // Should detect raw opacity literals
    expect(
      pattern.hasMatch("Opacity(opacity: settings.showImages ? 1 : 0.5,"),
      isTrue,
    );
    expect(
      pattern.hasMatch("Opacity(opacity: 0.3,"),
      isTrue,
    );

    // Should NOT detect when using S1Alpha token
    expect(
      pattern.hasMatch("opacity: S1Alpha.half,"),
      isFalse,
    );

    // Should NOT match unrelated patterns
    expect(pattern.hasMatch('opacity: 1.0,'), isFalse);
    expect(pattern.hasMatch('withValues(alpha: 0.08)'), isFalse);
  });

  test('divider-without-color rule detects bare Dividers', () {
    final pattern = RegExp(r'\bDivider\(');

    // Should detect Divider without color on same line
    expect(
      pattern
          .hasMatch('separatorBuilder: (_, __) => const Divider(height: 1),'),
      isTrue,
    );
    expect(
      pattern.hasMatch('const Divider(height: 1, indent: 16, endIndent: 16),'),
      isTrue,
    );
    expect(pattern.hasMatch('const Divider(height: 1)'), isTrue);

    // NOT match when color is present on same line
    expect(
      pattern.hasMatch(
        "Divider(color: Theme.of(ctx).colorScheme.outlineVariant)",
      ),
      isTrue, // pattern matches but lineFilter would exclude it
    );
  });

  test('vertical-divider-without-color rule detects bare VerticalDividers', () {
    final pattern = RegExp(r'\bVerticalDivider\(');

    expect(
      pattern.hasMatch('const VerticalDivider(width: 1, thickness: 1),'),
      isTrue,
    );

    // Should NOT match plain Divider
    expect(
      pattern.hasMatch('const Divider(height: 1),'),
      isFalse,
    );
  });
}
