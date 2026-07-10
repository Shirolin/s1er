// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter, undefined_prefixed_name
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';

/// 已注册的 HtmlElementView 工厂，避免每次 build 重复注册导致 WASM 内存损坏。
final Set<String> _registeredViewTypes = {};

/// Web 端用原生 HTML <img> 加载图片（绕过 CORS）
/// 必须包裹在有明确尺寸约束的父组件中，否则会触发无限尺寸布局错误
Widget buildWebImage(String url, {double? width, double? height, BoxFit fit = BoxFit.contain}) {
  final viewType = 'web-img-${url.hashCode}';

  if (!_registeredViewTypes.contains(viewType)) {
    _registeredViewTypes.add(viewType);
    ui_web.platformViewRegistry.registerViewFactory(viewType, (int viewId) {
      final img = html.ImageElement()
        ..src = url
        ..style.objectFit = _toCssFit(fit)
        ..style.display = 'block'
        ..style.margin = 'auto'
        ..style.width = '100%'
        ..style.height = '100%';
      return img;
    });
  }

  return SizedBox(
    width: width ?? 200,
    height: height ?? 200,
    child: HtmlElementView(viewType: viewType),
  );
}

/// Web 端通过 anchor 元素触发浏览器下载
void downloadImageWeb(String url, String fileName) {
  final anchor = html.AnchorElement(href: url)
    ..download = fileName
    ..style.display = 'none';
  html.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
}

/// Web 端检测图片宽高比，加载失败返回默认 16/9
Future<double> detectImageAspectRatio(String url) async {
  try {
    final img = html.ImageElement()..src = url;
    await img.onLoad.first;
    final w = img.naturalWidth;
    final h = img.naturalHeight;
    if (h > 0) return w / h;
  } catch (_) {}
  return 16 / 9;
}

String _toCssFit(BoxFit fit) {
  switch (fit) {
    case BoxFit.cover:
      return 'cover';
    case BoxFit.fill:
      return 'fill';
    case BoxFit.contain:
    default:
      return 'contain';
  }
}
