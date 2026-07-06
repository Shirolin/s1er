import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import '../utils/bbcode_parser.dart';
import 'emoticon_widget.dart';
import 'quote_block.dart';
import 'image_viewer.dart';

class BbcodeRenderer extends StatelessWidget {
  final String bbcode;

  const BbcodeRenderer({super.key, required this.bbcode});

  @override
  Widget build(BuildContext context) {
    if (bbcode.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: _buildParts(context, bbcode),
    );
  }

  List<Widget> _buildParts(BuildContext context, String text) {
    final widgets = <Widget>[];
    final quoteRegex = RegExp(r'\[quote\](.*?)\[/quote\]', dotAll: true);
    final matches = quoteRegex.allMatches(text).toList();

    if (matches.isEmpty) {
      final html = BbcodeParser.parse(text);
      widgets.add(_buildHtmlContent(html));
      return widgets;
    }

    int lastEnd = 0;
    for (final match in matches) {
      final before = text.substring(lastEnd, match.start);
      if (before.isNotEmpty) {
        widgets.add(_buildHtmlContent(BbcodeParser.parse(before)));
      }
      widgets.add(QuoteBlock(content: match.group(1)!));
      lastEnd = match.end;
    }

    final after = text.substring(lastEnd);
    if (after.isNotEmpty) {
      widgets.add(_buildHtmlContent(BbcodeParser.parse(after)));
    }

    return widgets;
  }

  Widget _buildHtmlContent(String html) {
    return Html(
      data: html,
      style: {
        'body': Style(fontSize: FontSize(14)),
        'blockquote': Style(display: Display.none),
        'img': Style(width: Width(200)),
      },
      extensions: [
        TagExtension(
          tagsToExtend: {'span'},
          builder: (context) {
            final element = context.element;
            if (element != null && element.classes.contains('emoticon')) {
              final code = element.attributes['data-code'] ?? '';
              return EmoticonWidget(code: code);
            }
            return const SizedBox.shrink();
          },
        ),
        TagExtension(
          tagsToExtend: {'img'},
          builder: (context) {
            final src = context.element?.attributes['src'] ?? '';
            return ImageViewer(imageUrl: src);
          },
        ),
      ],
    );
  }
}
