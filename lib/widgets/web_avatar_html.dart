// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter, undefined_prefixed_name
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';

Widget buildHtmlAvatar(String url, double radius, String fallback) {
  final viewType = 'avatar-$url';
  // 注册只做一次
  ui_web.platformViewRegistry.registerViewFactory(viewType, (int viewId) {
    final img = html.ImageElement()
      ..src = url
      ..style.width = '${radius * 2}px'
      ..style.height = '${radius * 2}px'
      ..style.objectFit = 'cover'
      ..style.borderRadius = '50%'
      ..style.display = 'block';
    img.onError.listen((_) {
      img.src = '';
      img.alt = fallback;
    });
    return img;
  });
  return ClipOval(
    child: SizedBox(
      width: radius * 2,
      height: radius * 2,
      child: HtmlElementView(viewType: viewType),
    ),
  );
}
