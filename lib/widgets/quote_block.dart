import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'bbcode_renderer.dart';

class QuoteBlock extends StatelessWidget {
  const QuoteBlock({
    super.key,
    required this.content,
    this.depth = 0,
    this.currentTid,
  });

  final String content;
  final int depth;
  final String? currentTid;

  static const _maxDepth = 3;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final effectiveDepth = depth.clamp(0, _maxDepth);

    final bgColor = Color.lerp(
      scheme.surfaceContainerHigh.withValues(alpha: 0.5),
      scheme.surfaceContainerHigh.withValues(alpha: 0.9),
      effectiveDepth / _maxDepth,
    )!;

    final borderColor = Color.lerp(
      scheme.primary.withValues(alpha: 0.5),
      scheme.tertiary.withValues(alpha: 0.8),
      effectiveDepth / _maxDepth,
    )!;

    final author = _extractAuthor(content);
    final link = _extractLink(content);
    final bodyContent = _removeHeader(content);

    final parsedLink = link != null ? _parsePostLink(link) : null;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border(left: BorderSide(color: borderColor, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (author != null || parsedLink != null)
            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(8),
                ),
                onTap: parsedLink != null
                    ? () => _navigateToPost(context, parsedLink)
                    : null,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
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
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 4, 10, 8),
            child: BbcodeRenderer(
              bbcode: bodyContent,
              quoteDepth: depth + 1,
              currentTid: currentTid,
            ),
          ),
        ],
      ),
    );
  }

  String? _extractLink(String text) {
    final match = RegExp(
      r'<a\s+href="([^"]*)"',
      caseSensitive: false,
    ).firstMatch(text);
    if (match != null) {
      var url = match.group(1) ?? '';
      url = url.replaceAll('&amp;', '&').replaceAll('&amp;amp;', '&');
      return url;
    }
    return null;
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

    result = result
        .replaceAll(RegExp(r'</div>$', caseSensitive: false), '')
        .trim();

    final authorLine = RegExp(
      r'^.*?发表于\s*\d{4}-\d{1,2}-\d{1,2}\s*\d{2}:\d{2}(?::\d{2})?\s*(?:<br\s*/?>|\n)?',
      multiLine: true,
      caseSensitive: false,
    ).firstMatch(result);
    if (authorLine != null) {
      result = result.substring(authorLine.end);
    }

    // 清理头部和尾部残余的 <br/> 标签以及空白换行
    result = result.replaceFirst(RegExp(r'^(?:\s*|<br\s*/?>)+', caseSensitive: false), '');
    result = result.replaceFirst(RegExp(r'(?:\s*|<br\s*/?>)+$', caseSensitive: false), '');

    return result;
  }

  ({String tid, String? pid})? _parsePostLink(String url) {
    final pidMatch = RegExp(r'pid=(\d+)').firstMatch(url);
    final ptidMatch = RegExp(r'ptid=(\d+)').firstMatch(url);

    if (ptidMatch != null) {
      return (
        tid: ptidMatch.group(1)!,
        pid: pidMatch?.group(1),
      );
    }
    return null;
  }

  void _navigateToPost(
    BuildContext context,
    ({String tid, String? pid}) link,
  ) {
    context.push('/thread/${link.tid}');
  }
}
