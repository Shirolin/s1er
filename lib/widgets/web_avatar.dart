import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'web_avatar_stub.dart'
    if (dart.library.html) 'web_avatar_html.dart';

/// 跨平台头像组件
/// Web: 用 HTML <img> 标签（不受 CORS 限制）
/// Native: 用 Image.network
class WebAvatar extends StatelessWidget {
  final String? url;
  final double radius;
  final String fallbackLetter;

  const WebAvatar({
    super.key,
    required this.url,
    this.radius = 40,
    required this.fallbackLetter,
  });

  @override
  Widget build(BuildContext context) {
    if (url == null || url!.isEmpty) {
      return _fallback();
    }
    if (kIsWeb) {
      return buildHtmlAvatar(url!, radius, fallbackLetter);
    }
    return ClipOval(
      child: Image.network(
        url!,
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
      child: Text(fallbackLetter, style: TextStyle(fontSize: radius * 0.8)),
    );
  }
}
