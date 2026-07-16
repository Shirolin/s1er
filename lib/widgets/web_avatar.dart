import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/resource_domains.dart';
import '../providers/connectivity_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/image_cache_provider.dart';
import '../utils/image_load_policy.dart';
import 'avatar_fallback.dart';
import 'force_show_images.dart';

/// 跨平台头像组件
/// Web: 通过代理加载（avatar 服务器未返回 CORS 头）
/// Native: 磁盘缓存 [CachedNetworkImage]
class WebAvatar extends ConsumerStatefulWidget {
  const WebAvatar({
    super.key,
    required this.url,
    this.radius = 40,
    required this.fallbackLetter,
  });

  final String? url;
  final double radius;
  final String fallbackLetter;

  /// Web 端将跨域图片 URL 改写为走本地代理
  static String _proxyUrl(String original) {
    return 'http://localhost:${ResourceDomains.proxyPort}'
        '/img-proxy?url=${Uri.encodeComponent(original)}';
  }

  @override
  ConsumerState<WebAvatar> createState() => _WebAvatarState();
}

class _WebAvatarState extends ConsumerState<WebAvatar> {
  bool _userRequestedLoad = false;
  bool? _hasDiskCache;

  @override
  void initState() {
    super.initState();
    _checkDiskCache();
  }

  @override
  void didUpdateWidget(WebAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _userRequestedLoad = false;
      _hasDiskCache = null;
      _checkDiskCache();
    }
  }

  Future<void> _checkDiskCache() async {
    final url = widget.url;
    if (url == null || url.isEmpty || kIsWeb) {
      if (mounted) setState(() => _hasDiskCache = false);
      return;
    }
    final cached = await hasCachedImage(url);
    if (mounted) setState(() => _hasDiskCache = cached);
  }

  bool _shouldAutoLoad() {
    if (ForceShowImages.read(context)) return true;
    final settings = ref.read(settingsProvider);
    final wifiConnected = ref.read(wifiConnectedProvider).value ?? true;
    return shouldAutoLoadInlineImages(
      showImages: true,
      policy: settings.avatarLoadPolicy,
      wifiConnected: wifiConnected,
      userRequested: _userRequestedLoad,
    );
  }

  void _requestLoad() {
    setState(() => _userRequestedLoad = true);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.url == null || widget.url!.isEmpty) {
      return _fallback(context);
    }

    ref.listen(
      settingsProvider.select((s) => s.avatarLoadPolicy),
      (previous, next) {
        if (_shouldAutoLoad()) setState(() {});
      },
    );
    ref.listen(wifiConnectedProvider, (previous, next) {
      if (_shouldAutoLoad()) setState(() {});
    });

    final canLoad = _hasDiskCache == true || _shouldAutoLoad();
    if (!canLoad) {
      return GestureDetector(
        onTap: _requestLoad,
        child: _fallback(context),
      );
    }

    final imageUrl = kIsWeb ? WebAvatar._proxyUrl(widget.url!) : widget.url!;
    final size = widget.radius * 2;
    return ClipOval(
      child: kIsWeb
          ? Image.network(
              imageUrl,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _fallback(context),
            )
          : CachedNetworkImage(
              imageUrl: imageUrl,
              cacheManager: s1ImageCacheManager,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorWidget: (_, __, ___) => _fallback(context),
            ),
    );
  }

  Widget _fallback(BuildContext context) {
    return AvatarFallbackLetter(
      radius: widget.radius,
      letter: widget.fallbackLetter,
    );
  }
}
