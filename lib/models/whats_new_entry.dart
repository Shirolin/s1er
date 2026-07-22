/// 单条应用内更新说明（随包 `whats_new.json`）。
class WhatsNewEntry {
  const WhatsNewEntry({
    required this.version,
    required this.date,
    required this.highlights,
  });

  factory WhatsNewEntry.fromJson(Map<String, dynamic> json) {
    final version = (json['version']?.toString() ?? '').trim();
    if (version.isEmpty) {
      throw const FormatException('version is required');
    }
    final highlightsRaw = json['highlights'];
    final highlights = <String>[];
    if (highlightsRaw is List) {
      for (final item in highlightsRaw) {
        final text = item?.toString().trim() ?? '';
        if (text.isNotEmpty) highlights.add(text);
      }
    }
    return WhatsNewEntry(
      version: version,
      date: (json['date']?.toString() ?? '').trim(),
      highlights: highlights,
    );
  }

  final String version;
  final String date;
  final List<String> highlights;
}
