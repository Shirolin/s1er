import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' show parseFragment;

/// 去除帖子正文中的作者特殊样式（字色 / 底色 / 字号），保留语义与结构。
///
/// 不修改 BBCode 解析缓存：本工具在渲染期基于解析后的 HTML 字符串工作，
/// 且无样式可剥离时原样返回（引用相等），供上层跳过重解析。
abstract final class AuthorStyleStripper {
  /// 需剥离的 style 声明键与 `<font>` 属性。
  static const Set<String> _stripStyleKeys = {
    'color',
    'background-color',
    'font-size',
  };
  static const Set<String> _stripFontAttrs = {'color', 'size'};

  /// 快速探测是否存在可剥离声明；无则直接返回原串。
  static final RegExp _styleHint = RegExp(
    r'color\s*[:=]|background-color\s*:|font-size\s*:|<font[^>]*\s(color|size)\s*=',
    caseSensitive: false,
  );

  static String strip(String html) {
    if (html.isEmpty || !_styleHint.hasMatch(html)) return html;

    final fragment = parseFragment(html);
    var changed = false;
    for (final node in fragment.nodes) {
      if (node is dom.Element && _stripElementTree(node)) changed = true;
    }
    if (!changed) return html;
    return fragment.outerHtml;
  }

  static bool _stripElementTree(dom.Element element) {
    var changed = _stripElement(element);
    for (final child in element.children) {
      if (_stripElementTree(child)) changed = true;
    }
    return changed;
  }

  static bool _stripElement(dom.Element element) {
    var changed = false;

    final style = element.attributes['style'];
    if (style != null && style.trim().isNotEmpty) {
      final kept = <String>[];
      for (final part in style.split(';')) {
        final trimmed = part.trim();
        if (trimmed.isEmpty) continue;
        final colon = trimmed.indexOf(':');
        if (colon <= 0) {
          kept.add(trimmed);
          continue;
        }
        final key = trimmed.substring(0, colon).trim().toLowerCase();
        if (_stripStyleKeys.contains(key)) {
          changed = true;
          continue;
        }
        kept.add(trimmed);
      }
      if (kept.isEmpty) {
        element.attributes.remove('style');
        changed = true;
      } else {
        final serialized = kept.join(';');
        if (serialized != style) {
          element.attributes['style'] = serialized;
          changed = true;
        }
      }
    }

    if (element.localName == 'font') {
      for (final attr in _stripFontAttrs) {
        if (element.attributes.containsKey(attr)) {
          element.attributes.remove(attr);
          changed = true;
        }
      }
      // `<font>` 无剩余属性时保留元素本身：flutter_html 按内联 span 渲染，
      // 子节点不受影响。
    }

    return changed;
  }
}
