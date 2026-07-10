// ignore_for_file: avoid_print
//
// Material Design 3 compliance audit for lib/**/*.dart.
// Usage: dart run scripts/audit_m3.dart [--fail-on-error] [--output=path]
//
// Exit code 1 when --fail-on-error and P0 violations are found.

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

final _rules = <AuditRule>[
  AuditRule(
    id: 'hardcoded-color-hex',
    severity: AuditSeverity.p0,
    message: 'Hardcoded Color(0x...) outside theme seeds',
    pattern: RegExp(r'Color\(0x'),
    fileFilter: (path) => !path.endsWith('lib/theme/app_theme.dart'),
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
    lineFilter: (line, path) {
      if (path.contains('bbcode_renderer.dart')) return false;
      if (path.contains('web_avatar')) return false;
      return true;
    },
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
    lineFilter: (line, path) {
      if (path.contains('web_avatar')) return false;
      return !line.contains('textTheme') &&
          !line.contains('contentTextStyle') &&
          !line.contains('//');
    },
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
    id: 'chip-display-badge',
    severity: AuditSeverity.warn,
    message: 'Chip( used — verify if Badge is more appropriate',
    pattern: RegExp(r'\bChip\('),
    fileFilter: (path) => path.contains('post_item.dart'),
  ),
];

List<String> _collectDartFiles(Directory root) {
  final files = <String>[];
  if (!root.existsSync()) return files;
  for (final entity in root.listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    final normalized = entity.path.replaceAll(r'\', '/');
    files.add(normalized);
  }
  files.sort();
  return files;
}

List<AuditFinding> _auditFile(String path) {
  final findings = <AuditFinding>[];
  final lines = File(path).readAsLinesSync();

  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    final lineNo = i + 1;

    // Card/AppBar non-zero elevation (multi-line heuristic within 8 lines).
    if (RegExp(r'\b(Card|AppBar)\b').hasMatch(line)) {
      final windowEnd = (i + 8).clamp(0, lines.length);
      final window = lines.sublist(i, windowEnd).join('\n');
      final elevMatch = RegExp(r'elevation:\s*([1-9]\d*)').firstMatch(window);
      if (elevMatch != null) {
        final elevLine = i + window.substring(0, elevMatch.start).split('\n').length;
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

    for (final rule in _rules) {
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

String _severityLabel(AuditSeverity s) => switch (s) {
      AuditSeverity.p0 => 'P0',
      AuditSeverity.p1 => 'P1',
      AuditSeverity.warn => 'WARN',
    };

String _formatReport(List<AuditFinding> findings, {required DateTime at}) {
  final buffer = StringBuffer()
    ..writeln('# M3 Compliance Audit Report')
    ..writeln()
    ..writeln('Generated: ${at.toIso8601String()}')
    ..writeln('Scanned: lib/')
    ..writeln();

  final p0 = findings.where((f) => f.severity == AuditSeverity.p0).length;
  final p1 = findings.where((f) => f.severity == AuditSeverity.p1).length;
  final warn = findings.where((f) => f.severity == AuditSeverity.warn).length;

  buffer
    ..writeln('## Summary')
    ..writeln()
    ..writeln('| Severity | Count |')
    ..writeln('|----------|-------|')
    ..writeln('| P0 | $p0 |')
    ..writeln('| P1 | $p1 |')
    ..writeln('| WARN | $warn |')
    ..writeln();

  if (findings.isEmpty) {
    buffer.writeln('No violations found.');
    return buffer.toString();
  }

  buffer.writeln('## Findings');
  buffer.writeln();

  final byFile = <String, List<AuditFinding>>{};
  for (final f in findings) {
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
  if (!libDir.existsSync()) {
    stderr.writeln('Error: lib/ directory not found. Run from project root.');
    exit(2);
  }

  final allFindings = <AuditFinding>[];
  for (final file in _collectDartFiles(libDir)) {
    allFindings.addAll(_auditFile(file));
  }

  final now = DateTime.now().toUtc();
  final report = _formatReport(allFindings, at: now);

  final defaultOutput =
      'reports/m3_audit_${now.toIso8601String().split('T').first}.md';
  final outFile = File(outputPath ?? defaultOutput);
  outFile.parent.createSync(recursive: true);
  outFile.writeAsStringSync(report);

  print(report);
  print('Report written to: ${outFile.path}');

  final p0Count =
      allFindings.where((f) => f.severity == AuditSeverity.p0).length;
  if (failOnError && p0Count > 0) {
    stderr.writeln('Audit failed: $p0Count P0 violation(s).');
    exit(1);
  }
}
