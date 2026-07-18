import 'package:flutter/material.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' show parseFragment;

import 'color_contrast.dart';

/// 作者色适配结果；`null` 表示删除该侧声明（继承主题默认）。
class AdaptedColors {
  const AdaptedColors({this.fg, this.bg});

  final Color? fg;
  final Color? bg;
}

/// 将帖子 HTML 中的作者字色/底色按当前 [ColorScheme] 做对比度门控与重映射。
abstract final class AuthorColorAdapter {
  static final RegExp _authorColorHint = RegExp(
    r'color\s*[:=]|background-color\s*:',
    caseSensitive: false,
  );

  /// HTML 16 色命名（与 flutter_html namedColors 对齐，查找时大小写不敏感）。
  static const Map<String, String> _namedColors = {
    'white': '#FFFFFF',
    'silver': '#C0C0C0',
    'gray': '#808080',
    'grey': '#808080',
    'black': '#000000',
    'red': '#FF0000',
    'maroon': '#800000',
    'yellow': '#FFFF00',
    'olive': '#808000',
    'lime': '#00FF00',
    'green': '#008000',
    'aqua': '#00FFFF',
    'teal': '#008080',
    'blue': '#0000FF',
    'navy': '#000080',
    'fuchsia': '#FF00FF',
    'purple': '#800080',
  };

  static final Map<_AdaptCacheKey, AdaptedColors> _lru = {};
  static final List<_AdaptCacheKey> _lruOrder = [];
  static const int _lruMax = 64;

  /// 解析 `#RGB` / `#RRGGBB` / HTML 命名色。
  static Color? parseCssColor(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return null;

    final named = _namedColors[value.toLowerCase()];
    if (named != null) return _parseHex(named);

    return _parseHex(value);
  }

  static Color? _parseHex(String raw) {
    var cleaned = raw.replaceAll('#', '').trim();
    if (cleaned.length == 3) {
      cleaned = cleaned.split('').map((c) => '$c$c').join();
    }
    if (cleaned.length != 6) return null;
    final value = int.tryParse(cleaned, radix: 16);
    if (value == null) return null;
    return Color.fromARGB(
      255,
      (value >> 16) & 0xFF,
      (value >> 8) & 0xFF,
      value & 0xFF,
    );
  }

  static String toCssHex(Color color) {
    final value = color.toARGB32() & 0xFFFFFF;
    return '#${value.toRadixString(16).padLeft(6, '0').toUpperCase()}';
  }

  /// 成对适配作者前景/背景；返回的 `null` 侧应删除对应 CSS 声明。
  static AdaptedColors adaptPair({
    Color? fg,
    Color? bg,
    required Color surface,
    required Color onSurface,
  }) {
    final hasFg = fg != null;
    final hasBg = bg != null;
    if (!hasFg && !hasBg) return const AdaptedColors();

    final key = _AdaptCacheKey(
      fg: fg?.toARGB32(),
      bg: bg?.toARGB32(),
      surface: surface.toARGB32(),
      onSurface: onSurface.toARGB32(),
    );
    final cached = _lru[key];
    if (cached != null) {
      _lruOrder.remove(key);
      _lruOrder.add(key);
      return cached;
    }

    final result = _adaptPairUncached(
      fg: fg,
      bg: bg,
      surface: surface,
      onSurface: onSurface,
    );
    _putLru(key, result);
    return result;
  }

  static AdaptedColors _adaptPairUncached({
    Color? fg,
    Color? bg,
    required Color surface,
    required Color onSurface,
  }) {
    final authorFg = fg;
    final authorBg = bg;
    final hasFg = authorFg != null;
    final hasBg = authorBg != null;

    var resultFg = authorFg;
    var effectiveFg = authorFg ?? onSurface;
    final effectiveBg = authorBg ?? surface;

    if (ColorContrast.meetsTextContrast(effectiveFg, effectiveBg)) {
      return AdaptedColors(
        fg: hasFg ? authorFg : null,
        bg: hasBg ? authorBg : null,
      );
    }

    if (authorFg != null) {
      final adjusted =
          _adjustForContrast(authorFg, effectiveBg, adjustingFg: true);
      if (adjusted != null &&
          ColorContrast.meetsTextContrast(adjusted, effectiveBg)) {
        effectiveFg = adjusted;
        resultFg = adjusted;
        if (authorBg == null ||
            ColorContrast.meetsTextContrast(effectiveFg, authorBg)) {
          return AdaptedColors(fg: resultFg, bg: authorBg);
        }
      }
    }

    if (authorBg != null) {
      final adjusted =
          _adjustForContrast(authorBg, effectiveFg, adjustingFg: false);
      if (adjusted != null &&
          ColorContrast.meetsTextContrast(effectiveFg, adjusted)) {
        return AdaptedColors(
          fg: hasFg ? effectiveFg : null,
          bg: adjusted,
        );
      }
    }

    if (authorFg != null) {
      final againstSurface = _adjustForContrast(
        resultFg ?? authorFg,
        surface,
        adjustingFg: true,
      );
      if (againstSurface != null &&
          ColorContrast.meetsTextContrast(againstSurface, surface)) {
        return AdaptedColors(fg: againstSurface);
      }
      return const AdaptedColors();
    }

    // 仅有背景且无法适配 → 丢弃背景
    return const AdaptedColors();
  }

  /// 保色相/饱和度，调整亮度使与 [against] 达到正文对比度。
  static Color? _adjustForContrast(
    Color color,
    Color against, {
    required bool adjustingFg,
  }) {
    if (ColorContrast.meetsTextContrast(
      adjustingFg ? color : against,
      adjustingFg ? against : color,
    )) {
      return color;
    }

    final hsl = HSLColor.fromColor(color);
    final againstLum = against.computeLuminance();

    // 前景：相对暗底抬亮、亮底压暗；背景：相对亮字压暗、暗字抬亮。
    final towardLight = adjustingFg ? againstLum < 0.5 : againstLum >= 0.5;

    var lo = towardLight ? hsl.lightness : 0.0;
    var hi = towardLight ? 1.0 : hsl.lightness;
    if ((hi - lo).abs() < 0.001) return null;

    Color? found;
    for (var i = 0; i < 14; i++) {
      final mid = (lo + hi) / 2;
      final candidate = hsl.withLightness(mid.clamp(0.0, 1.0)).toColor();
      final ok = adjustingFg
          ? ColorContrast.meetsTextContrast(candidate, against)
          : ColorContrast.meetsTextContrast(against, candidate);
      if (ok) {
        found = candidate;
        if (towardLight) {
          hi = mid;
        } else {
          lo = mid;
        }
      } else {
        if (towardLight) {
          lo = mid;
        } else {
          hi = mid;
        }
      }
    }
    return found;
  }

  /// 改写 HTML 中的作者色声明；无作者色时原样返回。
  static String adaptHtml(String html, ColorScheme scheme) {
    if (html.isEmpty || !_authorColorHint.hasMatch(html)) return html;

    final fragment = parseFragment(html);
    var changed = false;
    for (final node in fragment.nodes) {
      if (node is dom.Element) {
        if (_adaptElementTree(node, scheme)) changed = true;
      }
    }
    if (!changed) return html;
    return fragment.outerHtml;
  }

  static bool _adaptElementTree(dom.Element element, ColorScheme scheme) {
    var changed = _adaptElement(element, scheme);
    for (final child in element.children) {
      if (_adaptElementTree(child, scheme)) changed = true;
    }
    return changed;
  }

  static bool _adaptElement(dom.Element element, ColorScheme scheme) {
    final styleMap = _parseStyle(element.attributes['style']);
    final fontColorRaw = element.attributes['color'];

    Color? styleFg;
    Color? styleBg;
    Color? fontFg;

    if (styleMap.containsKey('color')) {
      styleFg = parseCssColor(styleMap['color']!);
    }
    if (styleMap.containsKey('background-color')) {
      styleBg = parseCssColor(styleMap['background-color']!);
    }
    if (fontColorRaw != null && fontColorRaw.isNotEmpty) {
      fontFg = parseCssColor(fontColorRaw);
    }

    final authorFg = styleFg ?? fontFg;
    if (authorFg == null && styleBg == null) return false;

    final adapted = adaptPair(
      fg: authorFg,
      bg: styleBg,
      surface: scheme.surface,
      onSurface: scheme.onSurface,
    );

    var changed = false;

    if (styleMap.containsKey('color') ||
        styleMap.containsKey('background-color')) {
      if (styleMap.containsKey('color')) {
        if (adapted.fg == null) {
          styleMap.remove('color');
          changed = true;
        } else {
          final hex = toCssHex(adapted.fg!);
          if (styleMap['color'] != hex) {
            styleMap['color'] = hex;
            changed = true;
          }
        }
      }
      if (styleMap.containsKey('background-color')) {
        if (adapted.bg == null) {
          styleMap.remove('background-color');
          changed = true;
        } else {
          final hex = toCssHex(adapted.bg!);
          if (styleMap['background-color'] != hex) {
            styleMap['background-color'] = hex;
            changed = true;
          }
        }
      }
      final serialized = _serializeStyle(styleMap);
      if (serialized == null || serialized.isEmpty) {
        if (element.attributes.containsKey('style')) {
          element.attributes.remove('style');
          changed = true;
        }
      } else if (element.attributes['style'] != serialized) {
        element.attributes['style'] = serialized;
        changed = true;
      }
    }

    if (fontColorRaw != null) {
      // font[color]：若 style 已有 color 则以 style 为准；否则写回/删除 font color。
      if (styleFg != null) {
        // 作者色已在 style 中处理；清理可能重复的低对比 font color。
        if (adapted.fg == null) {
          element.attributes.remove('color');
          changed = true;
        }
      } else if (adapted.fg == null) {
        element.attributes.remove('color');
        changed = true;
      } else {
        final hex = toCssHex(adapted.fg!);
        if (element.attributes['color'] != hex) {
          element.attributes['color'] = hex;
          changed = true;
        }
      }
    }

    return changed;
  }

  static Map<String, String> _parseStyle(String? style) {
    final map = <String, String>{};
    if (style == null || style.trim().isEmpty) return map;
    for (final part in style.split(';')) {
      final trimmed = part.trim();
      if (trimmed.isEmpty) continue;
      final colon = trimmed.indexOf(':');
      if (colon <= 0) continue;
      final key = trimmed.substring(0, colon).trim().toLowerCase();
      final value = trimmed.substring(colon + 1).trim();
      if (key.isEmpty || value.isEmpty) continue;
      map[key] = value;
    }
    return map;
  }

  static String? _serializeStyle(Map<String, String> map) {
    if (map.isEmpty) return null;
    return map.entries.map((e) => '${e.key}:${e.value}').join(';');
  }

  static void _putLru(_AdaptCacheKey key, AdaptedColors value) {
    if (_lru.containsKey(key)) {
      _lruOrder.remove(key);
    } else if (_lru.length >= _lruMax) {
      final oldest = _lruOrder.removeAt(0);
      _lru.remove(oldest);
    }
    _lru[key] = value;
    _lruOrder.add(key);
  }

  /// 测试用：清空 LRU。
  @visibleForTesting
  static void clearCache() {
    _lru.clear();
    _lruOrder.clear();
  }
}

class _AdaptCacheKey {
  const _AdaptCacheKey({
    required this.fg,
    required this.bg,
    required this.surface,
    required this.onSurface,
  });

  final int? fg;
  final int? bg;
  final int surface;
  final int onSurface;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _AdaptCacheKey &&
          fg == other.fg &&
          bg == other.bg &&
          surface == other.surface &&
          onSurface == other.onSurface;

  @override
  int get hashCode => Object.hash(fg, bg, surface, onSurface);
}
