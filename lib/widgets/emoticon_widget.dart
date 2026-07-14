import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../models/emoticon_catalog.dart';
import '../utils/platform_image_url.dart';

/// 显示 `[f:001]` / `f:001`：本地 asset 优先，失败再 CDN（Web 经代理）。
class EmoticonWidget extends StatelessWidget {
  const EmoticonWidget({
    super.key,
    required this.code,
    this.size = 24,
  });

  final String code;
  final double size;

  @override
  Widget build(BuildContext context) {
    final item = EmoticonCatalog.findByCode(code);
    final textTheme = Theme.of(context).textTheme;
    if (item == null) {
      return Text(code, style: textTheme.bodySmall);
    }
    return EmoticonImage(item: item, size: size);
  }
}

/// 面板与正文共用的表情图（asset → network）。
class EmoticonImage extends StatelessWidget {
  const EmoticonImage({
    super.key,
    required this.item,
    this.size = 32,
  });

  final EmoticonItem item;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final network = platformImageUrl(item.networkUrl, isWeb: kIsWeb);

    return Image.asset(
      item.assetPath,
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) {
        if (kIsWeb) {
          return Image.network(
            network,
            width: size,
            height: size,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => Icon(
              Icons.broken_image_outlined,
              size: size * 0.7,
              color: scheme.onSurfaceVariant,
            ),
          );
        }
        return CachedNetworkImage(
          imageUrl: network,
          width: size,
          height: size,
          fit: BoxFit.contain,
          fadeInDuration: Duration.zero,
          fadeOutDuration: Duration.zero,
          errorWidget: (_, __, ___) => Text(
            item.entity,
            style: textTheme.bodySmall,
          ),
        );
      },
    );
  }
}
