import 'package:flutter/material.dart';

import 'avatar_fallback.dart';

Widget buildHtmlAvatar(
  BuildContext context,
  String url,
  double radius,
  String fallback,
) {
  return AvatarFallbackLetter(radius: radius, letter: fallback);
}
