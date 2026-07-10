import 'dart:typed_data';

import 'package:flutter/material.dart';

Widget buildWebImage(String url, {double? width, double? height, BoxFit fit = BoxFit.contain}) {
  return Image.network(url, width: width, height: height, fit: fit);
}

Future<void> downloadImageWeb(Uint8List bytes, String fileName) async {
  throw UnsupportedError('downloadImageWeb is only available on web');
}
Future<double> detectImageAspectRatio(String url) async {
  return 16 / 9;
}
