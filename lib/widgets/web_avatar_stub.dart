import 'package:flutter/material.dart';

Widget buildHtmlAvatar(String url, double radius, String fallback) {
  return CircleAvatar(
    radius: radius,
    child: Text(fallback, style: TextStyle(fontSize: radius * 0.8)),
  );
}
