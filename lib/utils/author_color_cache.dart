import 'package:flutter/material.dart';

import 'author_color_adapter.dart';

/// LRU cache for theme-adapted HTML (avoids re-parseFragment on rebuild).
class AuthorColorCache {
  AuthorColorCache._();

  static const int maxEntries = 200;

  static final _cache = <_AuthorColorCacheKey, String>{};
  static final _order = <_AuthorColorCacheKey>[];

  static String adapt(String html, ColorScheme scheme, int themeToken) {
    if (html.isEmpty) return html;
    final key = _AuthorColorCacheKey(html, themeToken);
    final cached = _cache[key];
    if (cached != null) {
      _order.remove(key);
      _order.add(key);
      return cached;
    }
    final adapted = AuthorColorAdapter.adaptHtml(html, scheme);
    if (_cache.length >= maxEntries) {
      final oldest = _order.removeAt(0);
      _cache.remove(oldest);
    }
    _cache[key] = adapted;
    _order.add(key);
    return adapted;
  }

  static void clear() {
    _cache.clear();
    _order.clear();
  }
}

class _AuthorColorCacheKey {
  const _AuthorColorCacheKey(this.html, this.themeToken);

  final String html;
  final int themeToken;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _AuthorColorCacheKey &&
          html == other.html &&
          themeToken == other.themeToken;

  @override
  int get hashCode => Object.hash(identityHashCode(html), themeToken);
}
