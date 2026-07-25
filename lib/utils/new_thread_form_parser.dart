import 'package:html/parser.dart' show parse;

/// Parsed metadata from Discuz web new-thread editor HTML.
class NewThreadHtmlForm {
  const NewThreadHtmlForm({
    this.threadTypes = const {},
    this.typeRequired,
  });

  final Map<String, String> threadTypes;
  final bool? typeRequired;
}

String unwrapAjaxHtml(String body) {
  final cdataMatch = RegExp(
    r'<!\[CDATA\[(.*)\]\]>',
    dotAll: true,
  ).firstMatch(body);
  return cdataMatch?.group(1) ?? body;
}

bool isPlaceholderThreadTypeOption(String value, String label) {
  if (value != '0') return false;
  final text = label.trim();
  return text.isEmpty || text.contains('选择');
}

/// Parses `forum.php?mod=post&action=newthread` HTML for thread types.
NewThreadHtmlForm parseNewThreadFormHtml(String body) {
  final html = unwrapAjaxHtml(body);
  if (html.trim().isEmpty) {
    return const NewThreadHtmlForm();
  }

  final typeRequired = _parseTypeRequired(html);
  try {
    final document = parse(html);
    final types = <String, String>{};
    for (final option in document.querySelectorAll('select#typeid option')) {
      final value = option.attributes['value']?.trim() ?? '';
      if (value.isEmpty) continue;
      final label = option.text.trim();
      if (isPlaceholderThreadTypeOption(value, label)) continue;
      types[value] = label.isEmpty ? value : label;
    }
    return NewThreadHtmlForm(
      threadTypes: types,
      typeRequired: typeRequired,
    );
  } catch (_) {
    return NewThreadHtmlForm(typeRequired: typeRequired);
  }
}

bool? _parseTypeRequired(String html) {
  final match = RegExp(
    r'''var\s+typerequired\s*=\s*parseInt\(\s*['"](\d+)['"]\s*\)''',
  ).firstMatch(html);
  if (match == null) return null;
  return match.group(1) == '1';
}
