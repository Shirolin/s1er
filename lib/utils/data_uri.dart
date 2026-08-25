import 'dart:convert';
import 'dart:typed_data';

/// Inline `data:` image URLs (including malformed `http://data:` prefixes).
class DataUri {
  DataUri._();

  static final _malformedPrefix =
      RegExp(r'^https?://(?=data:)', caseSensitive: false);

  /// Unescape HTML entities and fix `http(s)://data:...` → `data:...`.
  static String normalizeImageUrl(String url) {
    final unescaped = url
        .replaceAll('&amp;', '&')
        .replaceAll('&#39;', "'")
        .replaceAll('&quot;', '"');
    return unescaped.replaceFirst(_malformedPrefix, '');
  }

  static bool isDataUri(String url) {
    return normalizeImageUrl(url).toLowerCase().startsWith('data:');
  }

  /// Returns decoded bytes, or null when [url] is not a data URI or invalid.
  static Uint8List? decode(String url) {
    final normalized = normalizeImageUrl(url);
    if (!normalized.toLowerCase().startsWith('data:')) return null;

    final comma = normalized.indexOf(',');
    if (comma < 0) return null;

    final meta = normalized.substring(0, comma).toLowerCase();
    final payload = normalized.substring(comma + 1);

    try {
      if (meta.contains(';base64')) {
        return base64Decode(payload);
      }
      return Uint8List.fromList(Uri.decodeComponent(payload).codeUnits);
    } on Object {
      return null;
    }
  }
}
