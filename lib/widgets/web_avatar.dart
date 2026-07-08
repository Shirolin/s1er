import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../config/resource_domains.dart';

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
      return _fallback();
    }
    final imageUrl = kIsWeb ? _proxyUrl(url!) : url!;
    return ClipOval(
      child: Image.network(
        imageUrl,
        width: radius * 2,
        height: radius * 2,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _fallback(),
      ),
    );
  }

  Widget _fallback() {
    return CircleAvatar(
      radius: radius,
      child: Text(fallbackLetter, style: TextStyle(fontSize: radius * 0.8)), // 动态计算：字体大小跟随头像半径缩放，无法使用 textTheme 固定层级
    );
  }
}
