/// Resolves preview (inline) vs full (tap-to-view) URLs for post images.
class PostImageUrls {
  const PostImageUrls({
    required this.previewUrl,
    required this.fullUrl,
  });

  final String previewUrl;
  final String fullUrl;

  bool get hasDistinctFull => previewUrl != fullUrl;

  /// [src] is the `<img src>`; [linkHref] is optional parent `<a href>`.
  static PostImageUrls resolve({
    required String src,
    String? linkHref,
  }) {
    final normalizedSrc = _normalizeUrl(src.trim());
    if (normalizedSrc.isEmpty) {
      return const PostImageUrls(previewUrl: '', fullUrl: '');
    }

    final normalizedLink = _normalizeOptionalUrl(linkHref);
    if (normalizedLink != null &&
        _isUsableImageLink(normalizedLink) &&
        normalizedLink != normalizedSrc) {
      return PostImageUrls(
        previewUrl: normalizedSrc,
        fullUrl: normalizedLink,
      );
    }

    final fullFromThumb = _fullFromThumbUrl(normalizedSrc);
    if (fullFromThumb != null) {
      return PostImageUrls(
        previewUrl: normalizedSrc,
        fullUrl: fullFromThumb,
      );
    }

    // 单 URL（无 anchor、非 thumb）不猜测 .thumb.jpg，避免大量 404。
    return PostImageUrls(
      previewUrl: normalizedSrc,
      fullUrl: normalizedSrc,
    );
  }

  static String _normalizeUrl(String url) {
    return url
        .replaceAll('&amp;', '&')
        .replaceAll('&#39;', "'")
        .replaceAll('&quot;', '"');
  }

  static String? _normalizeOptionalUrl(String? url) {
    if (url == null) return null;
    final trimmed = _normalizeUrl(url.trim());
    if (trimmed.isEmpty) return null;
    final lower = trimmed.toLowerCase();
    if (lower.startsWith('javascript:') ||
        lower.startsWith('#') ||
        lower == 'about:blank') {
      return null;
    }
    return trimmed;
  }

  static bool _isUsableImageLink(String url) {
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      return false;
    }
    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    if (uri.host.isEmpty) return false;
    return true;
  }

  static bool _looksLikeThumbUrl(String url) {
    final lower = url.toLowerCase();
    if (lower.endsWith('.thumb.jpg') || lower.endsWith('.thumb.png')) {
      return true;
    }
    if (RegExp(r'[_/]thumb\.(jpg|jpeg|png|webp)$', caseSensitive: false)
        .hasMatch(lower)) {
      return true;
    }
    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    final size = uri.queryParameters['size']?.toLowerCase() ?? '';
    if (uri.path.contains('forum.php') &&
        uri.queryParameters['mod'] == 'image' &&
        size.contains('fixwidth')) {
      return true;
    }
    return false;
  }

  static String? _fullFromThumbUrl(String url) {
    if (!_looksLikeThumbUrl(url)) return null;

    if (url.toLowerCase().endsWith('.thumb.jpg')) {
      return url.substring(0, url.length - '.thumb.jpg'.length);
    }
    if (url.toLowerCase().endsWith('.thumb.png')) {
      return url.substring(0, url.length - '.thumb.png'.length);
    }

    final thumbSuffix = RegExp(
      r'([._/])thumb\.(jpg|jpeg|png|webp)$',
      caseSensitive: false,
    );
    final match = thumbSuffix.firstMatch(url);
    if (match != null) {
      final separator = match.group(1)!;
      if (separator == '.') {
        return '${url.substring(0, match.start)}.${match.group(2)!}';
      }
      return url.substring(0, match.start);
    }

    final uri = Uri.tryParse(url);
    if (uri == null) return null;
    if (uri.path.contains('forum.php') &&
        uri.queryParameters['mod'] == 'image') {
      final params = Map<String, String>.from(uri.queryParameters);
      params.remove('size');
      params['size'] = 'source';
      return uri.replace(queryParameters: params).toString();
    }

    return null;
  }
}
