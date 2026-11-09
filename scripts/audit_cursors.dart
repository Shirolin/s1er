// Audits the desktop/web pointer policy for S1er.
//
// Policy (docs/adr/0010-desktop-mouse-cursor-policy.md): tappable surfaces must
// go through `S1InkWell` (which injects the hand cursor) or declare an explicit
// `mouseCursor:`. Flutter's built-in default
// (`WidgetStateMouseCursor.adaptiveClickable`) resolves to the plain arrow on
// desktop and has changed across Flutter releases; owning it keeps behaviour
// stable when the SDK is upgraded.
//
// Usage: dart run scripts/audit_cursors.dart [--fail-on-error]
import 'dart:io';

const _targets = <String>[
  'InkWell(',
  'InkResponse(',
  'ActionChip(',
  'FilterChip(',
  'ChoiceChip(',
  'InputChip(',
  'RawChip(',
  'Chip(',
];

/// A cursor is only required when the surface actually handles input.
/// Display-only chips/cards keep the default arrow on purpose.
const _interactiveCallbacks = <String>[
  'onTap:',
  'onDoubleTap:',
  'onLongPress:',
  'onPressed:',
  'onSelected:',
  'onDeleted:',
];

class Violation {
  Violation(this.file, this.line, this.name);
  final String file;
  final int line;
  final String name;

  @override
  String toString() => '$file:$line  $name missing mouseCursor:';
}

int _lineOf(String src, int offset) {
  var line = 1;
  for (var i = 0; i < offset && i < src.length; i++) {
    if (src[i] == '\n') line++;
  }
  return line;
}

/// Returns the index of the `)` matching the `(` at [open], or -1.
int _callEnd(String src, int open) {
  var depth = 0;
  var i = open;
  var inSingle = false, inDouble = false, inLine = false, inBlock = false;
  while (i < src.length) {
    final c = src[i];
    final n = i + 1 < src.length ? src[i + 1] : '';
    if (inLine) {
      if (c == '\n') inLine = false;
    } else if (inBlock) {
      if (c == '*' && n == '/') {
        inBlock = false;
        i++;
      }
    } else if (inSingle) {
      if (c == r'\') {
        i++;
      } else if (c == "'") {
        inSingle = false;
      }
    } else if (inDouble) {
      if (c == r'\') {
        i++;
      } else if (c == '"') {
        inDouble = false;
      }
    } else {
      if (c == '/' && n == '/') {
        inLine = true;
        i++;
      } else if (c == '/' && n == '*') {
        inBlock = true;
        i++;
      } else if (c == "'") {
        inSingle = true;
      } else if (c == '"') {
        inDouble = true;
      } else if (c == '(') {
        depth++;
      } else if (c == ')') {
        depth--;
        if (depth == 0) return i;
      }
    }
    i++;
  }
  return -1;
}

void main(List<String> args) {
  final failOnError = args.contains('--fail-on-error');
  final files = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  final violations = <Violation>[];
  for (final file in files) {
    final src = file.readAsStringSync();
    for (final target in _targets) {
      var idx = src.indexOf(target);
      while (idx >= 0) {
        final before = idx == 0 ? '' : src[idx - 1];
        final isIdentifierChar = RegExp(r'[A-Za-z0-9_]').hasMatch(before);
        if (!isIdentifierChar) {
          final open = idx + target.length - 1;
          final end = _callEnd(src, open);
          if (end > 0) {
            final body = src.substring(open, end + 1);
            final interactive =
                _interactiveCallbacks.any((cb) => body.contains(cb));
            if (interactive && !body.contains('mouseCursor:')) {
              violations.add(
                Violation(
                  file.path,
                  _lineOf(src, idx),
                  target.substring(0, target.length - 1),
                ),
              );
            }
          }
        }
        idx = src.indexOf(target, idx + target.length);
      }
    }
  }

  violations.sort((a, b) {
    final byFile = a.file.compareTo(b.file);
    return byFile != 0 ? byFile : a.line.compareTo(b.line);
  });

  if (violations.isEmpty) {
    // ignore: avoid_print
    print('audit_cursors: OK (${files.length} files scanned)');
    return;
  }

  // ignore: avoid_print
  print('audit_cursors: ${violations.length} violation(s)');
  for (final v in violations) {
    // ignore: avoid_print
    print('  $v');
  }
  if (failOnError) exit(1);
}
