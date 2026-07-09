import 'package:flutter/material.dart';

Widget buildWebImage(String url, {double? width, double? height, BoxFit fit = BoxFit.contain}) {
  return Image.network(url, width: width, height: height, fit: fit);
}

void downloadImageWeb(String url, String fileName) {
  throw UnsupportedError('downloadImageWeb is only available on web');
}
