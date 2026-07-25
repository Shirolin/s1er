/// Normalizes forum `readperm` option values for internal use.
///
/// Empty string and `"0"` both mean unlimited.
String normalizeReadPermValue(String raw) {
  final value = raw.trim();
  if (value.isEmpty || value == '0') return '';
  return value;
}

/// Merges `select#readperm` options into value → display label pairs.
///
/// Duplicate values merge labels with ` / `. Document order is preserved.
Map<String, String> mergeReadPermOptions(
  Iterable<({String value, String label})> options,
) {
  final merged = <String, String>{};

  for (final option in options) {
    final key = normalizeReadPermValue(option.value);
    final label = option.label.trim();

    if (key.isEmpty) {
      merged.putIfAbsent('', () => '不限');
      continue;
    }

    final displayLabel = label.isEmpty ? '≥ $key' : label;
    final existing = merged[key];
    if (existing == null) {
      merged[key] = displayLabel;
      continue;
    }

    final parts = existing.split(' / ');
    if (!parts.contains(displayLabel)) {
      merged[key] = '$existing / $displayLabel';
    }
  }

  return merged;
}

/// Resolves the selected read permission from form state or drafts.
String? normalizeSelectedReadPerm(String? raw) {
  if (raw == null) return null;
  return normalizeReadPermValue(raw);
}
