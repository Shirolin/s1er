import 'package:flutter/material.dart';

Widget buildWebImage(String url, {double? width, double? height, BoxFit fit = BoxFit.contain}) {
  return Image.network(url, width: width, height: height, fit: fit);
}

void downloadImageWeb(String url, String fileName) {
  // 非 Web 平台无操作
}
