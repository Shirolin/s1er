class PrivateMessage {
  const PrivateMessage({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.message,
    required this.dateline,
    required this.isOutgoing,
  });

  factory PrivateMessage.fromApiJson(
    Map<String, dynamic> json, {
    required String partnerUid,
  }) {
    final authorId = _firstNonEmpty([
      json['msgfromid'],
      json['authorid'],
    ]);
    return PrivateMessage(
      id: _firstNonEmpty([json['pmid'], json['plid']]),
      authorId: authorId,
      authorName: _firstNonEmpty([json['msgfrom'], json['author']]),
      message: _decodeMessage(
        _firstNonEmpty([json['message'], json['subject']]),
      ),
      dateline: int.tryParse(json['dateline']?.toString() ?? '') ?? 0,
      isOutgoing: authorId.isNotEmpty && authorId != partnerUid,
    );
  }

  final String id;
  final String authorId;
  final String authorName;
  final String message;
  final int dateline;
  final bool isOutgoing;

  static String _firstNonEmpty(List<dynamic> values) {
    for (final value in values) {
      final text = value?.toString().trim() ?? '';
      if (text.isNotEmpty) return text;
    }
    return '';
  }

  static String _decodeMessage(String value) {
    return value
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'</p\s*>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<[^>]+>'), '')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#039;', "'")
        .replaceAll('&#39;', "'")
        .replaceAll('&nbsp;', ' ')
        .trim();
  }
}

class PmConversationResult {
  const PmConversationResult({
    required this.items,
    this.currentPage = 1,
    this.totalPages = 1,
  });

  static const empty = PmConversationResult(items: []);

  final List<PrivateMessage> items;
  final int currentPage;
  final int totalPages;
}
