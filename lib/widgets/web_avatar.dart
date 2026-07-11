import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../config/resource_domains.dart';
import 'avatar_fallback.dart';

/// 跨平台头像组件
/// Web: 通过代理加载（avatar 服务器未返回 CORS 头）
/// Native: 用 Image.network 直加载
class WebAvatar extends StatelessWidget {

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
  Widget build(BuildContext context) {
    if (url == null || url!.isEmpty) {
      return _fallback(context);
    }
    final imageUrl = kIsWeb ? _proxyUrl(url!) : url!;
    return ClipOval(
      child: Image.network(
        imageUrl,
        width: radius * 2,
        height: radius * 2,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _fallback(context),
      ),
    );
  }

  Widget _fallback(BuildContext context) {
    return AvatarFallbackLetter(radius: radius, letter: fallbackLetter);
  }
}
