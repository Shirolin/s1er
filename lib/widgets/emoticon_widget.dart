import 'package:flutter/material.dart';
import '../models/emoticon.dart';

class EmoticonWidget extends StatelessWidget {

  const EmoticonWidget({super.key, required this.code});
  final String code;

  @override
  Widget build(BuildContext context) {
    final assetPath = EmoticonMap.getAssetPath(code);
    if (assetPath != null) {
      return Image.asset(
        assetPath,
        width: 20,
        height: 20,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          return Text(code, style: const TextStyle(fontSize: 12));
        },
      );
    }
    return Text(code, style: const TextStyle(fontSize: 12));
  }
}
