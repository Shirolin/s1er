import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/constants.dart';
import '../theme/app_theme.dart';
import '../utils/bbcode_parser.dart';
import '../utils/post_image_urls.dart';
import 'emoticon_widget.dart';
import 'quote_block.dart';
import 'image_viewer.dart';

String _unescapeHtml(String s) {
  return s
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'");
}

class BbcodeRenderer extends StatelessWidget {

  const BbcodeRenderer({
    super.key,
    required this.bbcode,
    this.quoteDepth = 0,
    this.currentTid,
  });
  final String bbcode;
  final int quoteDepth;
  final String? currentTid;

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
    final segments = _splitQuotes(text);

    for (final segment in segments) {
      if (segment.isQuote) {
        widgets.add(QuoteBlock(
          content: segment.text,
          depth: quoteDepth,
          currentTid: currentTid,
        ),);
      } else if (segment.text.trim().isNotEmpty) {
        // 清理段落开头和结尾的换行符与 <br/>，避免由引用块分割产生的多余前导/后导空白
        var cleanedText = segment.text.replaceFirst(RegExp(r'^(?:\s*|<br\s*/?>)+', caseSensitive: false), '');
        cleanedText = cleanedText.replaceFirst(RegExp(r'(?:\s*|<br\s*/?>)+$', caseSensitive: false), '');
        if (cleanedText.trim().isNotEmpty) {
          final html = BbcodeParser.parse(cleanedText);
          widgets.add(_buildHtmlContent(context, html));
        }
      }
    }

    return widgets;
  }

  List<_Segment> _splitQuotes(String text) {
    final segments = <_Segment>[];
    // 同时匹配 [quote]...[/quote] 和 <div class="reply_wrap">...</div>
    final regex = RegExp(
      r'\[quote\](.*?)\[/quote\]|<div\s+class="reply_wrap">(.*?)</div>',
      dotAll: true,
      caseSensitive: false,
    );
    int lastEnd = 0;

    for (final match in regex.allMatches(text)) {
      if (match.start > lastEnd) {
        segments.add(_Segment(text.substring(lastEnd, match.start), false));
      }
      // group(1) = [quote] 内容, group(2) = <div class="reply_wrap"> 内容
      final content = match.group(1) ?? match.group(2) ?? '';
      segments.add(_Segment(content, true));
      lastEnd = match.end;
    }

    if (lastEnd < text.length) {
      segments.add(_Segment(text.substring(lastEnd), false));
    }

    return segments;
  }

  Widget _buildHtmlContent(BuildContext context, String html) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final bodySize = S1Typography.bodySize(textTheme);
    final codeSize = S1Typography.codeSize(textTheme);
    final bodyLineHeight = S1Typography.bodyLineHeight(textTheme);
    final codeFontFamily = textTheme.bodySmall?.fontFamily ?? 'monospace';

    return Html(
      data: html,
      style: {
        'body': Style(
          fontSize: FontSize(bodySize),
          lineHeight: LineHeight.number(bodyLineHeight),
          margin: Margins.zero,
          padding: HtmlPaddings.zero,
          color: scheme.onSurface,
          fontFamily: textTheme.bodyMedium?.fontFamily,
        ),
        'a': Style(
          color: scheme.primary,
          textDecoration: TextDecoration.none,
          fontWeight: FontWeight.w500,
        ),
        'b': Style(fontWeight: FontWeight.bold),
        'i': Style(fontStyle: FontStyle.italic),
        'u': Style(textDecoration: TextDecoration.underline),
        's': Style(textDecoration: TextDecoration.lineThrough),
        'pre': Style(
          backgroundColor: scheme.surfaceContainerHighest,
          padding: HtmlPaddings.all(12),
          margin: Margins.symmetric(vertical: 8),
          fontFamily: codeFontFamily,
          fontSize: FontSize(codeSize),
          display: Display.block,
        ),
        '.hide-content': Style(
          color: Colors.transparent,
          backgroundColor: scheme.outlineVariant,
        ),
        'blockquote': Style(display: Display.none),
        'hr': Style(
          border: Border(bottom: BorderSide(color: scheme.outlineVariant, width: 0.8)),
          margin: Margins.symmetric(vertical: 12),
        ),
        'ul': Style(padding: HtmlPaddings.only(left: 16)),
        'ol': Style(padding: HtmlPaddings.only(left: 16)),
        'li': Style(margin: Margins.only(bottom: 8)),
      },
      onLinkTap: (url, _, __) {
        if (url != null) {
          launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
        }
      },
      extensions: [
        TagExtension(
          tagsToExtend: {'span'},
          builder: (context) {
            final element = context.element;
            if (element == null) return const SizedBox.shrink();

            if (element.classes.contains('post-image')) {
              final preview =
                  _unescapeHtml(element.attributes['data-preview'] ?? '');
              final full =
                  _unescapeHtml(element.attributes['data-full'] ?? preview);
              if (preview.isEmpty) return const SizedBox.shrink();

              return ImageViewer(
                imageUrl: preview,
                fullImageUrl: full,
                showBorder: true,
                margin: const EdgeInsets.symmetric(vertical: 8),
              );
            }

            if (element.classes.contains('emoticon')) {
              final src = _unescapeHtml(element.attributes['data-src'] ?? '');
              if (src.isNotEmpty) {
                return ImageViewer(
                  imageUrl: src,
                  isEmoticon: true,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                );
              }
              final code = element.attributes['data-code'] ?? '';
              return EmoticonWidget(code: code);
            }

            return const SizedBox.shrink();
          },
        ),
        TagExtension(
          tagsToExtend: {'img'},
          builder: (context) {
            final src = _unescapeHtml(context.element?.attributes['src'] ?? '');
            if (src.isEmpty) return const SizedBox.shrink();

            if (S1Constants.isEmoticon(src)) {
              return ImageViewer(
                imageUrl: src,
                isEmoticon: true,
                margin: const EdgeInsets.symmetric(horizontal: 2),
              );
            }

            final urls = PostImageUrls.resolve(src: src);
            return ImageViewer(
              imageUrl: urls.previewUrl,
              fullImageUrl: urls.fullUrl,
              showBorder: true,
              margin: const EdgeInsets.symmetric(vertical: 8),
            );
          },
        ),
      ],
    );
  }
}

class _Segment {
  const _Segment(this.text, this.isQuote);
  final String text;
  final bool isQuote;
}

