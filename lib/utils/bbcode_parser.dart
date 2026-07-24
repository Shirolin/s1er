import 'package:html/dom.dart';
import 'package:html/parser.dart' show parseFragment;
import '../config/constants.dart';
import '../models/emoticon_catalog.dart';
import 'author_color_adapter.dart';
import 'html_optimizer.dart';
import 'post_image_index_counter.dart';
import 'post_image_urls.dart';

class BbcodeParser {
  static String parse(
    String input, {
    PostImageIndexCounter? imageIndexCounter,
  }) {
    if (input.isEmpty) return '';

    var output = input;

    output = _preClean(output);
    output = _convertBbcodeToHtml(output);
    output = _normalizeHtml(output, imageIndexCounter: imageIndexCounter);

    return output;
  }

  static int countPostImages(String parsedHtml) {
    final indexRegex = RegExp(r'data-image-index="(\d+)"');
    var maxIndex = -1;
    for (final match in indexRegex.allMatches(parsedHtml)) {
      final index = int.tryParse(match.group(1) ?? '') ?? -1;
      if (index > maxIndex) maxIndex = index;
    }
    if (maxIndex >= 0) return maxIndex + 1;

    return RegExp(r'class="post-image"').allMatches(parsedHtml).length;
  }

  static String _preClean(String text) {
    var output = text;
    output = output
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&amp;', '&')
        .replaceAll('&nbsp;', ' ');

    output = output.replaceAllMapped(
      RegExp(r'&#x([0-9a-fA-F]+);'),
      (m) => String.fromCharCode(int.parse(m.group(1)!, radix: 16)),
    );
    output = output.replaceAllMapped(
      RegExp(r'&#(\d+);'),
      (m) => String.fromCharCode(int.parse(m.group(1)!)),
    );

    output =
        output.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '<br/>');
    output = output.replaceAll(RegExp(r'<br/>\s*\r?\n'), '<br/>');
    output =
        output.replaceAll(RegExp(r'(<br/>\s*|[\n\r]\s*){3,}'), '<br/><br/>');

    return output;
  }

  static String _convertBbcodeToHtml(String text) {
    var output = text;

    output = output.replaceAllMapped(
      RegExp(r'\[b\](.*?)\[/b\]', dotAll: true),
      (m) => '<b>${m.group(1)}</b>',
    );
    output = output.replaceAllMapped(
      RegExp(r'\[i\](.*?)\[/i\]', dotAll: true),
      (m) => '<i>${m.group(1)}</i>',
    );
    output = output.replaceAllMapped(
      RegExp(r'\[u\](.*?)\[/u\]', dotAll: true),
      (m) => '<u>${m.group(1)}</u>',
    );
    output = output.replaceAllMapped(
      RegExp(r'\[s\](.*?)\[/s\]', dotAll: true),
      (m) => '<s>${m.group(1)}</s>',
    );

    output = output.replaceAllMapped(
      RegExp(r'\[url=(.*?)\](.*?)\[/url\]', dotAll: true),
      (m) => '<a href="${_escapeAttr(m.group(1)!)}">${m.group(2)}</a>',
    );
    output = output.replaceAllMapped(
      RegExp(r'\[url\](.*?)\[/url\]', dotAll: true),
      (m) {
        final href = _escapeAttr(m.group(1)!);
        return '<a href="$href">${m.group(1)}</a>';
      },
    );

    output = output.replaceAllMapped(
      RegExp(r'\[img\](.*?)\[/img\]', dotAll: true),
      (m) => '<img src="${_escapeAttr(m.group(1)!)}" />',
    );

    output = output.replaceAllMapped(
      RegExp(r'\[color=(.*?)\](.*?)\[/color\]', dotAll: true),
      (m) {
        final color = m.group(1)!.trim();
        final body = m.group(2)!;
        if (AuthorColorAdapter.parseCssColor(color) == null) return body;
        return '<span style="color:${_escapeAttr(color)}">$body</span>';
      },
    );
    output = output.replaceAllMapped(
      RegExp(r'\[backcolor=(.*?)\](.*?)\[/backcolor\]', dotAll: true),
      (m) {
        final color = m.group(1)!.trim();
        final body = m.group(2)!;
        if (AuthorColorAdapter.parseCssColor(color) == null) return body;
        return '<span style="background-color:${_escapeAttr(color)}">$body</span>';
      },
    );
    output = output.replaceAllMapped(
        RegExp(r'\[size=(\d+)\](.*?)\[/size\]', dotAll: true), (m) {
      final size = int.tryParse(m.group(1)!) ?? 14;
      return '<span style="font-size:${size.clamp(10, 24)}px">${m.group(2)}</span>';
    });

    output = output.replaceAllMapped(
      RegExp(r'\[quote\](.*?)\[/quote\]', dotAll: true),
      (m) => '<blockquote>${m.group(1)}</blockquote>',
    );
    output = output.replaceAllMapped(
      RegExp(r'\[code\](.*?)\[/code\]', dotAll: true),
      (m) => '<pre>${m.group(1)}</pre>',
    );
    output = output.replaceAllMapped(
      RegExp(r'\[hide=(\d+)\](.*?)\[/hide\]', dotAll: true),
      (m) => '<span class="hide-content">${m.group(2)}</span>',
    );
    output = output.replaceAllMapped(
      RegExp(r'\[hide\](.*?)\[/hide\]', dotAll: true),
      (m) => '<span class="hide-content">${m.group(1)}</span>',
    );

    output =
        output.replaceAll(RegExp(r'\[hr\]', caseSensitive: false), '<hr/>');
    output = output.trim();
    output = output.replaceAll('\n', '<br/>');
    output = output.replaceAllMapped(
      RegExp(r'\[([facdgb]):(\d+)\]', caseSensitive: false),
      (m) {
        final prefix = m.group(1)!.toLowerCase();
        final digits = m.group(2)!;
        return '<span class="emoticon" data-code="$prefix:$digits">[emoticon]</span>';
      },
    );

    return output;
  }

  static String _normalizeHtml(
    String html, {
    PostImageIndexCounter? imageIndexCounter,
  }) {
    var output = html;

    final fragment = parseFragment(output);

    // Convert div.reply_wrap to blockquote to ensure style, depth classes and quote headers are applied
    fragment.querySelectorAll('div.reply_wrap').forEach((div) {
      final bq = Element.tag('blockquote');
      bq.attributes.addAll(div.attributes);
      while (div.nodes.isNotEmpty) {
        bq.append(div.nodes.first);
      }
      div.replaceWith(bq);
    });

    // Strip RateLog HTML blocks to prevent performance degradation and crashes
    fragment.querySelectorAll('h3.psth').forEach((e) => e.remove());
    fragment.querySelectorAll('div[id^="ratelog_"]').forEach((e) => e.remove());

    // Strip or flatten interactive/platform-view-triggering tags on ALL platforms.
    // flutter_html renders <input>/<button>/<textarea>/<select> etc. via PlatformView
    // on native, which causes lifecycle assertion crashes during fast list scrolling.
    // Media embeds (iframe/video/audio) are similarly unsafe in native list views.
    // Strategy: replace with their visible text content (if any), or remove entirely.
    const formTags = {
      'input',
      'button',
      'textarea',
      'select',
      'option',
      'optgroup',
      'form',
    };
    const mediaEmbedTags = {
      'iframe',
      'video',
      'audio',
      'embed',
      'object',
      'source',
      'track',
    };
    for (final tag in {...formTags, ...mediaEmbedTags}) {
      fragment.querySelectorAll(tag).forEach((el) {
        final visibleText = el.text.trim();
        if (visibleText.isNotEmpty) {
          el.replaceWith(Text(visibleText));
        } else {
          el.remove();
        }
      });
    }

    // Process blockquotes to attach depth classes and extract quote headers
    _processBlockquotes(fragment);

    fragment.querySelectorAll('div.img').forEach((div) {
      final replacement = _replacementForImageBlock(
        div,
        imageIndexCounter: imageIndexCounter,
      );
      if (replacement != null) {
        div.replaceWith(replacement);
      }
    });

    // 扁平化合并连续相同属性的 HTML 标签，减少 DOM 节点数量
    HtmlOptimizer.flatten(fragment);

    output = fragment.outerHtml;

    output = output.replaceAll('<br>', '<br/>');
    output = _replaceImgTags(output, imageIndexCounter: imageIndexCounter);

    return output;
  }

  static Element? _replacementForImageBlock(
    Element div, {
    PostImageIndexCounter? imageIndexCounter,
  }) {
    final img = div.querySelector('img');
    if (img == null) return null;

    final src = img.attributes['src'] ?? '';
    if (src.isEmpty) return null;

    if (S1Constants.isEmoticon(src)) {
      return _emoticonSpan(src);
    }

    final anchor = div.querySelector('a');
    final href = anchor?.attributes['href'];
    return _postImageSpan(
      PostImageUrls.resolve(src: src, linkHref: href),
      imageIndexCounter: imageIndexCounter,
    );
  }

  static String _replaceImgTags(
    String html, {
    PostImageIndexCounter? imageIndexCounter,
  }) {
    var output = html;

    output = output.replaceAllMapped(
      RegExp(r'<img\s[^>]*src="([^"]*)"[^>]*/?>', caseSensitive: false),
      (m) {
        final src = m.group(1) ?? '';
        if (src.isEmpty) return m.group(0)!;
        if (S1Constants.isEmoticon(src)) {
          return _emoticonSpan(src).outerHtml;
        }
        return _postImageSpan(
          PostImageUrls.resolve(src: src),
          imageIndexCounter: imageIndexCounter,
        ).outerHtml;
      },
    );

    output = output.replaceAllMapped(
      RegExp(r"<img\s[^>]*src='([^']*)'[^>]*/?>", caseSensitive: false),
      (m) {
        final src = m.group(1) ?? '';
        if (src.isEmpty) return m.group(0)!;
        if (S1Constants.isEmoticon(src)) {
          return _emoticonSpan(src).outerHtml;
        }
        return _postImageSpan(
          PostImageUrls.resolve(src: src),
          imageIndexCounter: imageIndexCounter,
        ).outerHtml;
      },
    );

    return output;
  }

  static Element _emoticonSpan(String src) {
    final span = Element.tag('span');
    span.classes.add('emoticon');
    span.attributes['data-src'] = src;
    final item = EmoticonCatalog.fromSmileyUrl(src);
    if (item != null) {
      span.attributes['data-code'] = item.dataCode;
    }
    span.text = '[emoticon]';
    return span;
  }

  static Element _postImageSpan(
    PostImageUrls urls, {
    PostImageIndexCounter? imageIndexCounter,
  }) {
    final span = Element.tag('span');
    span.classes.add('post-image');
    span.attributes['data-preview'] = urls.previewUrl;
    span.attributes['data-full'] = urls.fullUrl;
    if (imageIndexCounter != null) {
      span.attributes['data-image-index'] =
          imageIndexCounter.assign().toString();
    }
    return span;
  }

  static List<String> extractImages(String html) {
    final previewRegex = RegExp(r'data-preview="([^"]+)"');
    final previews =
        previewRegex.allMatches(html).map((m) => m.group(1)!).toList();
    if (previews.isNotEmpty) return previews;

    final regex = RegExp(r'<img[^>]+src="([^"]+)"');
    return regex.allMatches(html).map((m) => m.group(1)!).toList();
  }

  static String stripTags(String html) {
    return html.replaceAll(RegExp(r'<[^>]*>'), '');
  }

  /// HTML 属性值转义，防止 BBCode 参数打断属性引号。
  static String _escapeAttr(String value) {
    return value
        .replaceAll('&', '&amp;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;');
  }

  static int _countBlockquoteAncestors(Element e) {
    var count = 0;
    var parent = e.parent;
    while (parent != null) {
      if (parent.localName == 'blockquote') {
        count++;
      }
      parent = parent.parent;
    }
    return count;
  }

  static void _processBlockquotes(DocumentFragment fragment) {
    fragment.querySelectorAll('blockquote').forEach((bq) {
      final ancestors = _countBlockquoteAncestors(bq);
      bq.classes.add('quote-depth-${ancestors + 1}');

      Element? headerElement;
      String? authorText;
      String? href;

      final anchor = bq.querySelector('a');
      if (anchor != null &&
          (anchor.text.contains('发表于') ||
              (anchor.attributes['href']?.contains('mod=redirect') ?? false))) {
        headerElement = anchor;
        authorText = anchor.text.trim();
        href = anchor.attributes['href'];
      }

      if (headerElement == null) {
        final font = bq.querySelector('font');
        if (font != null && font.text.contains('发表于')) {
          headerElement = font;
          authorText = font.text.trim();
        }
      }

      if (headerElement != null) {
        var top = headerElement;
        while (top.parent != bq && top.parent != null) {
          top = top.parent!;
        }

        final header = Element.tag('quote-header')
          ..attributes['author'] = authorText ?? '引用'
          ..attributes['href'] = href ?? '';

        top.replaceWith(header);

        final parent = header.parent;
        if (parent != null) {
          final index = parent.nodes.indexOf(header);
          if (index != -1) {
            var nextIdx = index + 1;
            while (nextIdx < parent.nodes.length) {
              final nextNode = parent.nodes[nextIdx];
              if (nextNode is Text && nextNode.text.trim().isEmpty) {
                nextIdx++;
                continue;
              }
              if (nextNode is Element && nextNode.localName == 'br') {
                nextNode.remove();
              }
              break;
            }
          }
        }
      }
    });
  }
}
