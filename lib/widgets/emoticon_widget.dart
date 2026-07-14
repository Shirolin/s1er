import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../models/emoticon.dart';
import '../models/emoticon_catalog.dart';

class EmoticonWidget extends StatelessWidget {
  const EmoticonWidget({super.key, required this.code});
  final String code;

  static const double _size = 24;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final assetPath = EmoticonMap.getAssetPath(_normalizeEntity(code));
    if (assetPath != null) {
      return Image.asset(
        assetPath,
        width: _size,
        height: _size,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) =>
            _networkOrText(context, textTheme),
      );
    }
    return _networkOrText(context, textTheme);
  }

  Widget _networkOrText(BuildContext context, TextTheme textTheme) {
    final item = EmoticonCatalog.findByCode(code);
    if (item == null) {
      return Text(_displayCode(code), style: textTheme.bodySmall);
    }

    if (kIsWeb) {
      return Image.network(
        item.pngUrl,
        width: _size,
        height: _size,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => Image.network(
          item.gifUrl,
          width: _size,
          height: _size,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) =>
              Text(item.entity, style: textTheme.bodySmall),
        ),
      );
    }

    return CachedNetworkImage(
      imageUrl: item.pngUrl,
      width: _size,
      height: _size,
      fit: BoxFit.contain,
      fadeInDuration: Duration.zero,
      fadeOutDuration: Duration.zero,
      errorWidget: (_, __, ___) => CachedNetworkImage(
        imageUrl: item.gifUrl,
        width: _size,
        height: _size,
        fit: BoxFit.contain,
        fadeInDuration: Duration.zero,
        fadeOutDuration: Duration.zero,
        errorWidget: (_, __, ___) =>
            Text(item.entity, style: textTheme.bodySmall),
      ),
    );
  }

  static String _normalizeEntity(String raw) {
    final trimmed = raw.trim();
    if (trimmed.startsWith('[') && trimmed.endsWith(']')) return trimmed;
    if (RegExp(r'^[facdgb]:\d+$', caseSensitive: false).hasMatch(trimmed)) {
      return '[$trimmed]';
    }
    return trimmed;
  }

  static String _displayCode(String raw) {
    final item = EmoticonCatalog.findByCode(raw);
    return item?.entity ?? raw;
  }
}
