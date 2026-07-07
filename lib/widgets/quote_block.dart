import 'package:flutter/material.dart';
import 'bbcode_renderer.dart';

class QuoteBlock extends StatelessWidget {

  const QuoteBlock({super.key, required this.content});
  final String content;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.5),
        border: Border(
          left: BorderSide(
            color: Theme.of(context).colorScheme.primary,
            width: 3,
          ),
        ),
      ),
      child: BbcodeRenderer(bbcode: content),
    );
  }
}
