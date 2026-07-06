class BbcodeParser {
  static String parse(String input) {
    if (input.isEmpty) return '';

    var output = input;
    output = _escapeHtml(output);
    output = _convertTags(output);
    return output;
  }

  static String _escapeHtml(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;');
  }

  static String _convertTags(String text) {
    var output = text;

    // Bold
    output = output.replaceAllMapped(
      RegExp(r'\[b\](.*?)\[/b\]', dotAll: true),
      (m) => '<b>${m.group(1)}</b>',
    );

    // Italic
    output = output.replaceAllMapped(
      RegExp(r'\[i\](.*?)\[/i\]', dotAll: true),
      (m) => '<i>${m.group(1)}</i>',
    );

    // Underline
    output = output.replaceAllMapped(
      RegExp(r'\[u\](.*?)\[/u\]', dotAll: true),
      (m) => '<u>${m.group(1)}</u>',
    );

    // Strikethrough
    output = output.replaceAllMapped(
      RegExp(r'\[s\](.*?)\[/s\]', dotAll: true),
      (m) => '<s>${m.group(1)}</s>',
    );

    // Color
    output = output.replaceAllMapped(
      RegExp(r'\[color=(.*?)\](.*?)\[/color\]', dotAll: true),
      (m) => '<span style="color:${m.group(1)}">${m.group(2)}</span>',
    );

    // Size
    output = output.replaceAllMapped(
      RegExp(r'\[size=(\d+)\](.*?)\[/size\]', dotAll: true),
      (m) => '<span style="font-size:${m.group(1)}px">${m.group(2)}</span>',
    );

    // Images
    output = output.replaceAllMapped(
      RegExp(r'\[img\](.*?)\[/img\]', dotAll: true),
      (m) => '<img src="${m.group(1)}" />',
    );

    // URLs with text
    output = output.replaceAllMapped(
      RegExp(r'\[url=(.*?)\](.*?)\[/url\]', dotAll: true),
      (m) => '<a href="${m.group(1)}">${m.group(2)}</a>',
    );

    // URLs without text
    output = output.replaceAllMapped(
      RegExp(r'\[url\](.*?)\[/url\]', dotAll: true),
      (m) => '<a href="${m.group(1)}">${m.group(1)}</a>',
    );

    // Quote
    output = output.replaceAllMapped(
      RegExp(r'\[quote\](.*?)\[/quote\]', dotAll: true),
      (m) => '<blockquote>${m.group(1)}</blockquote>',
    );

    // Code
    output = output.replaceAllMapped(
      RegExp(r'\[code\](.*?)\[/code\]', dotAll: true),
      (m) => '<pre>${m.group(1)}</pre>',
    );

    // Emoticons [f:xxx]
    output = output.replaceAllMapped(
      RegExp(r'\[f:(\d+)\]'),
      (m) =>
          '<span class="emoticon" data-code="f:${m.group(1)}">[emoticon]</span>',
    );

    // Lists
    output = output.replaceAll('[*]', '<li>');

    // Newlines
    output = output.replaceAll('\n', '<br>');

    return output;
  }

  static List<String> extractImages(String html) {
    final regex = RegExp(r'<img[^>]+src="([^"]+)"');
    return regex.allMatches(html).map((m) => m.group(1)!).toList();
  }

  static String stripTags(String html) {
    return html.replaceAll(RegExp(r'<[^>]*>'), '');
  }
}
