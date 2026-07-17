import 'package:flutter/material.dart';
import '../models/thread_destination.dart';
import '../theme/app_theme.dart';
import '../utils/internal_navigation.dart';
import '../utils/post_image_index_counter.dart';
import '../utils/quote_jump.dart';
import '../utils/thread_navigation.dart';
import 'bbcode_renderer.dart';

class QuoteBlock extends StatelessWidget {
  const QuoteBlock({
    super.key,
    required this.content,
    required this.imageIndexCounter,
    this.depth = 0,
    this.currentTid,
    this.imagesExpanded = false,
    this.onExpandImages,
  });

  final String content;
  final PostImageIndexCounter imageIndexCounter;
  final int depth;
  final String? currentTid;
  final bool imagesExpanded;
  final VoidCallback? onExpandImages;

  static const _maxDepth = 3;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final effectiveDepth = depth.clamp(0, _maxDepth);

    final bgColor = effectiveDepth >= 2
        ? scheme.surfaceContainerHighest
        : effectiveDepth >= 1
            ? scheme.surfaceContainerHigh
            : scheme.surfaceContainer;

    final borderColor = effectiveDepth >= 2
        ? scheme.tertiary
        : effectiveDepth >= 1
            ? scheme.primary
            : scheme.outlineVariant;

    final author = _extractAuthor(content);
    final link = QuoteJumpParser.extractLink(content);
    final bodyContent = _removeHeader(content);

    final parsedLink = link != null
        ? QuoteJumpParser.parsePostLink(link, fallbackTid: currentTid)
        : null;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: S1Shape.small,
        border: Border(left: BorderSide(color: borderColor, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (author != null || parsedLink != null)
            Material(
              color: Colors.transparent,
              child: Semantics(
                button: parsedLink != null,
                label: parsedLink != null ? '跳转到引用帖子' : null,
                child: InkWell(
                  borderRadius: S1Shape.small,
                  onTap: parsedLink != null
                      ? () => _navigateToPost(context, parsedLink)
                      : null,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.format_quote,
                          size: 15,
                          color: scheme.primary,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            author ?? '引用',
                            style: textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: scheme.primary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (parsedLink != null)
                          Icon(
                            Icons.open_in_new,
                            size: 13,
                            color: scheme.onSurfaceVariant,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
            child: BbcodeRenderer(
              bbcode: bodyContent,
              imageIndexCounter: imageIndexCounter,
              quoteDepth: depth + 1,
              currentTid: currentTid,
              imagesExpanded: imagesExpanded,
              onExpandImages: onExpandImages,
            ),
          ),
        ],
      ),
    );
  }

  String? _extractAuthor(String text) {
    final match = RegExp(
      r'<font[^>]*>(.*?)</font>',
      caseSensitive: false,
    ).firstMatch(text);
    if (match != null) {
      final inner = match.group(1)?.trim() ?? '';
      if (inner.contains('发表于')) return inner;
    }

    final match2 = RegExp(
      r'>([^<]*?发表于\s*\d{4}-\d{1,2}-\d{1,2}\s*\d{2}:\d{2}(?::\d{2})?)',
    ).firstMatch(text);
    if (match2 != null) return match2.group(1)?.trim();

    final match3 = RegExp(
      r'^.*?said:\s*$',
      multiLine: true,
    ).firstMatch(text);
    if (match3 != null) return match3.group(0)?.trim();

    return null;
  }

  String _removeHeader(String text) {
    var result = text;

    final divMatch = RegExp(
      r'<div\s+class="reply_wrap">\s*',
      caseSensitive: false,
    ).firstMatch(result);
    if (divMatch != null) {
      result = result.substring(divMatch.end);
    }

    final aTagEnd = RegExp(
      r'<a\s+[^>]*>.*?发表于.*?</a>\s*(?:<br\s*/?>)?',
      caseSensitive: false,
    ).firstMatch(result);

    if (aTagEnd != null) {
      result = result.substring(aTagEnd.end);
    } else {
      final fontTagEnd = RegExp(
        r'<font\s+[^>]*>[^<]*?发表于[^<]*?</font>\s*(?:<br\s*/?>)?',
        caseSensitive: false,
      ).firstMatch(result);
      if (fontTagEnd != null) {
        result = result.substring(fontTagEnd.end);
      }
    }

    result =
        result.replaceAll(RegExp(r'</div>$', caseSensitive: false), '').trim();

    final authorLine = RegExp(
      r'^.*?发表于\s*\d{4}-\d{1,2}-\d{1,2}\s*\d{2}:\d{2}(?::\d{2})?\s*(?:<br\s*/?>|\n)?',
      multiLine: true,
      caseSensitive: false,
    ).firstMatch(result);
    if (authorLine != null) {
      result = result.substring(authorLine.end);
    }

    result = result.replaceFirst(
      RegExp(r'^(?:\s*|<br\s*/?>)+', caseSensitive: false),
      '',
    );
    result = result.replaceFirst(
      RegExp(r'(?:\s*|<br\s*/?>)+$', caseSensitive: false),
      '',
    );

    return result;
  }

  void _navigateToPost(
    BuildContext context,
    ({String tid, String? pid}) link,
  ) {
    final destination = link.pid != null
        ? ThreadPost(link.tid, link.pid!)
        : ResumeThread(link.tid);
    openInternalLocation(context, ThreadRouteCodec.encodePath(destination));
  }
}
