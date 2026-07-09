import 'package:flutter/material.dart';
import '../models/emoticon.dart';

class EmoticonWidget extends StatelessWidget {

  const EmoticonWidget({super.key, required this.code});
  final String code;

  @override
  Widget build(BuildContext context) {
    final assetPath = EmoticonMap.getAssetPath(code);
    final textTheme = Theme.of(context).textTheme;
    if (assetPath != null) {
      return Image.asset(
        assetPath,
        width: 24,
        height: 24,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          return Text(code, style: textTheme.bodySmall);
        },
      );
    }
    return Text(code, style: textTheme.bodySmall);
  }
}
