// ignore_for_file: avoid_print
//
// Material Design 3 compliance audit.
// Scans lib/ (P0/P1/WARN) and test/ (WARN for missing AppTheme).
// Allowed patterns: see AGENTS.md「M3 允许模式」
//
// Usage: dart run scripts/audit_m3.dart [--fail-on-error] [--output=path]

import 'dart:io';

enum AuditSeverity { p0, p1, warn }

class AuditFinding {
  AuditFinding({
    required this.ruleId,
    required this.severity,
    required this.file,
    required this.line,
    required this.message,
    required this.snippet,
  });

  final String ruleId;
  final AuditSeverity severity;
  final String file;
  final int line;
  final String message;
  final String snippet;
}

class AuditRule {
  AuditRule({
    required this.id,
    required this.severity,
    required this.message,
    required this.pattern,
    this.fileFilter,
    this.lineFilter,
  });

  final String id;
  final AuditSeverity severity;
  final String message;
  final RegExp pattern;
  final bool Function(String path)? fileFilter;
  final bool Function(String line, String path)? lineFilter;
}

final _libRules = <AuditRule>[
  AuditRule(
    id: 'hardcoded-color-hex',
    severity: AuditSeverity.p0,
    message: 'Hardcoded Color(0x...) outside allowed files',
    pattern: RegExp(r'Color\(0x'),
    fileFilter: (path) =>
        !path.endsWith('lib/theme/app_theme.dart') &&
        !path.endsWith('lib/utils/poll_bar_color.dart'),
  ),
  AuditRule(
    id: 'hardcoded-colors-semantic',
    severity: AuditSeverity.p0,
    message: 'Hardcoded Colors.* (non-transparent)',
    pattern: RegExp(r'Colors\.(?!transparent\b)\w+'),
    fileFilter: (path) => !path.endsWith('lib/theme/app_theme.dart'),
  ),
  AuditRule(
    id: 'bare-font-size',
    severity: AuditSeverity.p0,
    message: 'Bare fontSize literal in TextStyle',
    pattern: RegExp(r'fontSize:\s*\d'),
  ),
  AuditRule(
    id: 'fontsize-numeric-fallback',
    severity: AuditSeverity.p1,
    message: 'Numeric font size fallback — use S1Typography',
    pattern: RegExp(r'\?\?\s*\d+(\.0)?'),
    fileFilter: (path) => path.contains('lib/widgets/bbcode_renderer.dart'),
    lineFilter: (line, _) =>
        line.contains('fontSize') || line.contains('FontSize'),
  ),
  AuditRule(
    id: 'inline-alpha-literal',
    severity: AuditSeverity.p1,
    message: 'Inline alpha literal — use S1Alpha token',
    pattern: RegExp(r'withValues\(alpha:\s*0\.\d+'),
    lineFilter: (line, _) => !line.contains('S1Alpha'),
  ),
  AuditRule(
    id: 'm2-components',
    severity: AuditSeverity.p0,
    message: 'Deprecated M2 component or useMaterial3: false',
    pattern: RegExp(
      r'RaisedButton|BottomNavigationBar|ToggleButtons|useMaterial3:\s*false',
    ),
  ),
  AuditRule(
    id: 'elevated-button',
    severity: AuditSeverity.p0,
    message: 'ElevatedButton should prefer FilledButton in M3',
    pattern: RegExp(r'\bElevatedButton\b'),
  ),
  AuditRule(
    id: 'text-style-without-theme',
    severity: AuditSeverity.p0,
    message: 'TextStyle( without textTheme base on same line',
    pattern: RegExp(r'TextStyle\('),
    lineFilter: (line, _) =>
        !line.contains('textTheme') &&
        !line.contains('contentTextStyle') &&
        !line.contains('//'),
  ),
  AuditRule(
    id: 'inline-border-radius',
    severity: AuditSeverity.p1,
    message: 'BorderRadius.circular without S1Shape token',
    pattern: RegExp(r'BorderRadius\.circular'),
    lineFilter: (line, _) => !line.contains('S1Shape'),
  ),
  AuditRule(
    id: 'theme-data-outside-theme',
    severity: AuditSeverity.p1,
    message: 'ThemeData( constructed outside lib/theme/',
    pattern: RegExp(r'ThemeData\('),
    fileFilter: (path) => !path.contains('lib/theme/'),
  ),
  AuditRule(
    id: 'raw-snackbar',
    severity: AuditSeverity.p1,
    message: 'Direct SnackBar( instead of S1SnackBar',
    pattern: RegExp(r'\bSnackBar\('),
    fileFilter: (path) =>
        !path.endsWith('lib/utils/s1_snack_bar.dart') &&
        !path.endsWith('lib/theme/app_theme.dart'),
  ),
  AuditRule(
    id: 'opacity-raw-value',
    severity: AuditSeverity.p1,
    message: 'Raw opacity literal in Opacity widget — use S1Alpha token',
    // Exclude 0.0 and 1.0 which are common animation endpoints
    pattern: RegExp(r'Opacity\(opacity:.*\b(?![01]\.0\b)0\.\d+'),
    lineFilter: (line, _) => !line.contains('S1Alpha'),
  ),
];

List<String> _collectDartFiles(Directory root) {
  final files = <String>[];
  if (!root.existsSync()) return files;
  for (final entity in root.listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    files.add(entity.path.replaceAll(r'\', '/'));
  }
  files.sort();
  return files;
}

void _checkMissingExplicitElevation(
    String path, List<String> lines, List<AuditFinding> findings) {
  if (!path.startsWith('lib/')) return;

  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    if (!RegExp(r'\b(Card|AppBar)\s*\(').hasMatch(line)) continue;

    final windowEnd = (i + 6).clamp(0, lines.length);
    final window = lines.sublist(i, windowEnd).join('\n');
    if (RegExp(r'elevation:\s*0').hasMatch(window)) continue;

    findings.add(
      AuditFinding(
        ruleId: 'missing-explicit-elevation',
        severity: AuditSeverity.p1,
        file: path,
        line: i + 1,
        message: 'Card/AppBar should explicitly set elevation: 0',
        snippet: line.trim(),
      ),
    );
  }
}

void _checkDividerColor(
    String path, List<String> lines, List<AuditFinding> findings) {
  if (!path.startsWith('lib/')) return;
  // Skip the theme file - Divider there is DividerThemeData.
  if (path.endsWith('lib/theme/app_theme.dart')) return;

  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    if (!RegExp(r'\b(Divider|VerticalDivider)\s*\(').hasMatch(line)) continue;
    // Skip commented-out code
    if (line.trimLeft().startsWith('//')) continue;
    // Skip DividerThemeData constructors
    if (line.contains('DividerThemeData')) continue;

    // Look ahead up to 6 lines for the color parameter
    final windowEnd = (i + 6).clamp(0, lines.length);
    final window = lines.sublist(i, windowEnd).join('\n');
    if (RegExp(r'\bcolor:\s*').hasMatch(window)) continue;

    findings.add(
      AuditFinding(
        ruleId: 'divider-without-color',
        severity: AuditSeverity.p1,
        file: path,
        line: i + 1,
        message:
            'Divider/VerticalDivider without explicit color — should use colorScheme.outlineVariant',
        snippet: line.trim(),
      ),
    );
  }
}

List<AuditFinding> _auditLibFile(String path) {
  final findings = <AuditFinding>[];
  final lines = File(path).readAsLinesSync();

  _checkMissingExplicitElevation(path, lines, findings);
  _checkDividerColor(path, lines, findings);

  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    final lineNo = i + 1;

    if (RegExp(r'\b(Card|AppBar)\b').hasMatch(line)) {
      final windowEnd = (i + 8).clamp(0, lines.length);
      final window = lines.sublist(i, windowEnd).join('\n');
      final elevMatch = RegExp(r'elevation:\s*([1-9]\d*)').firstMatch(window);
      if (elevMatch != null) {
        final elevLine =
            i + window.substring(0, elevMatch.start).split('\n').length;
        findings.add(
          AuditFinding(
            ruleId: 'nonzero-card-appbar-elevation',
            severity: AuditSeverity.p0,
            file: path,
            line: elevLine,
            message: 'Card/AppBar elevation must be 0 for M3',
            snippet: lines[elevLine - 1].trim(),
          ),
        );
      }
    }

    for (final rule in _libRules) {
      if (rule.fileFilter != null && !rule.fileFilter!(path)) continue;
      if (!rule.pattern.hasMatch(line)) continue;
      if (rule.lineFilter != null && !rule.lineFilter!(line, path)) continue;

      findings.add(
        AuditFinding(
          ruleId: rule.id,
          severity: rule.severity,
          file: path,
          line: lineNo,
          message: rule.message,
          snippet: line.trim(),
        ),
      );
    }
  }

  return findings;
}

List<AuditFinding> _auditTestFile(String path) {
  final findings = <AuditFinding>[];
  if (path.contains('test/helpers/') ||
      path.contains('test/tool/audit_m3_test.dart')) {
    return findings;
  }

  final content = File(path).readAsLinesSync().join('\n');
  if (!content.contains('MaterialApp')) return findings;

  final usesAppTheme =
      content.contains('AppTheme.') || content.contains('wrapWithAppTheme');

  if (!usesAppTheme) {
    findings.add(
      AuditFinding(
        ruleId: 'test-missing-apptheme',
        severity: AuditSeverity.warn,
        file: path,
        line: 1,
        message:
            'Widget test uses MaterialApp without AppTheme / wrapWithAppTheme',
        snippet: 'MaterialApp(...)',
      ),
    );
  }

  return findings;
}

String _severityLabel(AuditSeverity s) => switch (s) {
      AuditSeverity.p0 => 'P0',
      AuditSeverity.p1 => 'P1',
      AuditSeverity.warn => 'WARN',
    };

String _formatReport(
  List<AuditFinding> libFindings,
  List<AuditFinding> testFindings, {
  required DateTime at,
}) {
  final all = [...libFindings, ...testFindings];
  final buffer = StringBuffer()
    ..writeln('# M3 Compliance Audit Report')
    ..writeln()
    ..writeln('Generated: ${at.toIso8601String()}')
    ..writeln('Scanned: lib/ + test/')
    ..writeln();

  final p0 = all.where((f) => f.severity == AuditSeverity.p0).length;
  final p1 = all.where((f) => f.severity == AuditSeverity.p1).length;
  final warn = all.where((f) => f.severity == AuditSeverity.warn).length;

  buffer
    ..writeln('## Summary')
    ..writeln()
    ..writeln('| Severity | Count |')
    ..writeln('|----------|-------|')
    ..writeln('| P0 | $p0 |')
    ..writeln('| P1 | $p1 |')
    ..writeln('| WARN | $warn |')
    ..writeln();

  if (all.isEmpty) {
    buffer.writeln('No violations found.');
  } else {
    buffer.writeln('## Findings');
    buffer.writeln();

    final byFile = <String, List<AuditFinding>>{};
    for (final f in all) {
      byFile.putIfAbsent(f.file, () => []).add(f);
    }

    for (final entry in byFile.entries) {
      buffer.writeln('### `${entry.key}`');
      buffer.writeln();
      for (final f in entry.value) {
        buffer.writeln(
          '- **[${_severityLabel(f.severity)}] ${f.ruleId}** (L${f.line}): ${f.message}',
        );
        buffer.writeln('  ```dart');
        buffer.writeln('  ${f.snippet}');
        buffer.writeln('  ```');
      }
      buffer.writeln();
    }
  }

  buffer.writeln('See AGENTS.md「M3 允许模式」for documented allowed patterns.');
  return buffer.toString();
}

void main(List<String> args) {
  final failOnError = args.contains('--fail-on-error');
  String? outputPath;
  for (final arg in args) {
    if (arg.startsWith('--output=')) {
      outputPath = arg.substring('--output='.length);
    }
  }

  final libDir = Directory('lib');
  final testDir = Directory('test');
  if (!libDir.existsSync()) {
    stderr.writeln('Error: lib/ directory not found. Run from project root.');
    exit(2);
  }

  final libFindings = <AuditFinding>[];
  for (final file in _collectDartFiles(libDir)) {
    libFindings.addAll(_auditLibFile(file));
  }

  final testFindings = <AuditFinding>[];
  if (testDir.existsSync()) {
    for (final file in _collectDartFiles(testDir)) {
      testFindings.addAll(_auditTestFile(file));
    }
  }

  final now = DateTime.now().toUtc();
  final report = _formatReport(libFindings, testFindings, at: now);

  final defaultOutput =
      'reports/m3_audit_${now.toIso8601String().split('T').first}.md';
  final outFile = File(outputPath ?? defaultOutput);
  outFile.parent.createSync(recursive: true);
  outFile.writeAsStringSync(report);

  print(report);
  print('Report written to: ${outFile.path}');

  final p0Count =
      libFindings.where((f) => f.severity == AuditSeverity.p0).length;
  if (failOnError && p0Count > 0) {
    stderr.writeln('Audit failed: $p0Count P0 violation(s).');
    exit(1);
  }
}
