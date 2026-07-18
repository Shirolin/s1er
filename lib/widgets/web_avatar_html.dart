// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter, undefined_prefixed_name
import 'package:flutter/material.dart';

import 'avatar_fallback.dart';

Widget buildHtmlAvatar(
  BuildContext context,
  String url,
  double radius,
  String fallback,
) {
  return ClipOval(
    child: Image.network(
      url,
      width: radius * 2,
      height: radius * 2,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => AvatarFallbackLetter(
        radius: radius,
        letter: fallback,
      ),
    ),
  );
}
