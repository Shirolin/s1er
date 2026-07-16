import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/constants.dart';
import '../models/emoticon_catalog.dart';
import '../providers/settings_provider.dart';
import '../theme/app_theme.dart';
import '../utils/bbcode_cache.dart';
import '../utils/bbcode_parser.dart';
import '../utils/post_image_index_counter.dart';
import '../utils/post_image_urls.dart';
import '../utils/quote_jump.dart';
import 'emoticon_widget.dart';
import 'force_show_images.dart';
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

class BbcodeRenderer extends ConsumerWidget {
  const BbcodeRenderer({
    super.key,
    required this.bbcode,
    required this.imageIndexCounter,
    this.quoteDepth = 0,
    this.currentTid,
    this.imagesExpanded = false,
    this.onExpandImages,
  });

  final String bbcode;
  final PostImageIndexCounter imageIndexCounter;
  final int quoteDepth;
  final String? currentTid;
  final bool imagesExpanded;
  final VoidCallback? onExpandImages;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (bbcode.isEmpty) return const SizedBox.shrink();

    // Subscribe to theme updates so memoized HTML blocks rebuild on theme change.
    Theme.of(context).colorScheme;

    final isForce = ForceShowImages.of(context);
    final showImages = isForce
        ? true
        : ref.watch(
            settingsProvider.select((s) => s.showImages),
          );
    final maxImagesPerPost = isForce
        ? 0
        : ref.watch(
            settingsProvider.select((s) => s.maxImagesPerPost),
          );
    final effectiveImagesExpanded = isForce ? true : imagesExpanded;
    final deferImages = !isForce;

    final widgets = _buildParts(
      context,
      bbcode,
      showImages: showImages,
      maxImagesPerPost: maxImagesPerPost,
      deferImages: deferImages,
      effectiveImagesExpanded: effectiveImagesExpanded,
    );
    final totalImages = imageIndexCounter.assignedCount;
    final maxVal = maxImagesPerPost;
    final hiddenCount =
        (!effectiveImagesExpanded && maxVal > 0 && totalImages > maxVal)
            ? totalImages - maxVal
            : 0;

    if (hiddenCount > 0 && showImages && onExpandImages != null) {
      widgets.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: ActionChip(
            avatar: Icon(
              Icons.image_outlined,
              size: 18,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            label: Text('还有 $hiddenCount 张图片，点击展开'),
            onPressed: onExpandImages,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }

  List<Widget> _buildParts(
    BuildContext context,
    String text, {
    required bool showImages,
    required int maxImagesPerPost,
    bool deferImages = true,
    bool effectiveImagesExpanded = false,
  }) {
    final widgets = <Widget>[];
    final segments = BbcodeQuoteSplitter.split(text);

    for (final segment in segments) {
      if (segment.isQuote) {
        widgets.add(
          QuoteBlock(
            content: segment.text,
            depth: quoteDepth,
            currentTid: currentTid,
            imageIndexCounter: imageIndexCounter,
            imagesExpanded: effectiveImagesExpanded,
            onExpandImages: onExpandImages,
          ),
        );
      } else if (segment.text.trim().isNotEmpty) {
        var cleanedText = segment.text.replaceFirst(
          RegExp(r'^(?:\s*|<br\s*/?>)+', caseSensitive: false),
          '',
        );
        cleanedText = cleanedText.replaceFirst(
          RegExp(r'(?:\s*|<br\s*/?>)+$', caseSensitive: false),
          '',
        );
        if (cleanedText.trim().isNotEmpty) {
          final html = _parseSegmentHtml(
            cleanedText,
            showImages: showImages,
            maxImagesPerPost: maxImagesPerPost,
          );
          widgets.add(
            _MemoizedHtmlBlock(
              html: html,
              showImages: showImages,
              maxImagesPerPost: maxImagesPerPost,
              imagesExpanded: effectiveImagesExpanded,
              imageIndexCounter: imageIndexCounter,
              onExpandImages: onExpandImages,
              deferImages: deferImages,
            ),
          );
        }
      }
    }

    return widgets;
  }

  String _parseSegmentHtml(
    String cleanedText, {
    required bool showImages,
    required int maxImagesPerPost,
  }) {
    final cacheKey = BbcodeCache.buildKey(
      message: cleanedText,
      showImages: showImages,
      maxImagesPerPost: maxImagesPerPost,
      quoteDepth: quoteDepth,
    );
    final cached = BbcodeCache.get(cacheKey);
    if (cached != null) {
      _advanceImageIndexFromHtml(cached);
      return cached;
    }
    final html = BbcodeParser.parse(
      cleanedText,
      imageIndexCounter: imageIndexCounter,
    );
    BbcodeCache.put(cacheKey, html);
    return html;
  }

  void _advanceImageIndexFromHtml(String html) {
    final count = BbcodeParser.countPostImages(html);
    for (var i = 0; i < count; i++) {
      imageIndexCounter.assign();
    }
  }
}

class _MemoizedHtmlBlock extends StatefulWidget {
  const _MemoizedHtmlBlock({
    required this.html,
    required this.showImages,
    required this.maxImagesPerPost,
    required this.imagesExpanded,
    required this.imageIndexCounter,
    this.onExpandImages,
    this.deferImages = true,
  });

  final String html;
  final bool showImages;
  final int maxImagesPerPost;
  final bool imagesExpanded;
  final PostImageIndexCounter imageIndexCounter;
  final VoidCallback? onExpandImages;
  final bool deferImages;

  @override
  State<_MemoizedHtmlBlock> createState() => _MemoizedHtmlBlockState();
}

class _MemoizedHtmlBlockState extends State<_MemoizedHtmlBlock> {
  late String _cachedHtml;
  late bool _cachedShowImages;
  late int _cachedMaxImages;
  late bool _cachedImagesExpanded;
  int? _cachedThemeToken;
  Widget? _cachedWidget;

  @override
  void initState() {
    super.initState();
    _cachedHtml = widget.html;
    _cachedShowImages = widget.showImages;
    _cachedMaxImages = widget.maxImagesPerPost;
    _cachedImagesExpanded = widget.imagesExpanded;
  }

  @override
  void didUpdateWidget(_MemoizedHtmlBlock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.html != _cachedHtml ||
        widget.showImages != _cachedShowImages ||
        widget.maxImagesPerPost != _cachedMaxImages ||
        widget.imagesExpanded != _cachedImagesExpanded) {
      _cachedHtml = widget.html;
      _cachedShowImages = widget.showImages;
      _cachedMaxImages = widget.maxImagesPerPost;
      _cachedImagesExpanded = widget.imagesExpanded;
      _cachedWidget = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final themeToken = Object.hash(
      scheme.brightness,
      scheme.primary,
      scheme.onSurface,
      scheme.surfaceContainerHighest,
    );
    if (themeToken != _cachedThemeToken) {
      _cachedThemeToken = themeToken;
      _cachedWidget = null;
    }
    _cachedWidget ??= _buildHtml(context);
    return _cachedWidget!;
  }

  Widget _buildHtml(BuildContext context) {
    final html = widget.html;
    final showImages = widget.showImages;
    final maxImagesPerPost = widget.maxImagesPerPost;
    final imagesExpanded = widget.imagesExpanded;

    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final bodySize = S1Typography.bodySize(textTheme);
    final codeSize = S1Typography.codeSize(textTheme);
    final bodyLineHeight = S1Typography.bodyLineHeight(textTheme);
    final codeFontFamily = textTheme.bodySmall?.fontFamily ?? 'monospace';

    bool shouldShowPostImage(int index) {
      if (!showImages) return false;
      if (maxImagesPerPost <= 0 || imagesExpanded) return true;
      return index < maxImagesPerPost;
    }

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
          border: Border(
            bottom: BorderSide(color: scheme.outlineVariant, width: 0.8),
          ),
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
              final full = _unescapeHtml(
                element.attributes['data-full'] ?? preview,
              );
              if (preview.isEmpty) return const SizedBox.shrink();

              final index = int.tryParse(
                    element.attributes['data-image-index'] ?? '',
                  ) ??
                  0;
              if (!shouldShowPostImage(index)) {
                return const SizedBox.shrink();
              }

              return ImageViewer(
                imageUrl: preview,
                fullImageUrl: full,
                showBorder: true,
                margin: const EdgeInsets.symmetric(vertical: 8),
                deferUntilVisible: widget.deferImages,
              );
            }

            if (element.classes.contains('emoticon')) {
              final src = _unescapeHtml(element.attributes['data-src'] ?? '');
              final code = element.attributes['data-code'] ?? '';
              final fromUrl =
                  src.isNotEmpty ? EmoticonCatalog.fromSmileyUrl(src) : null;
              final item = fromUrl ?? EmoticonCatalog.findByCode(code);
              if (item != null) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: EmoticonImage(item: item, size: 24),
                );
              }
              if (src.isNotEmpty) {
                return ImageViewer(
                  imageUrl: src,
                  isEmoticon: true,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                );
              }
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
              final item = EmoticonCatalog.fromSmileyUrl(src);
              if (item != null) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: EmoticonImage(item: item, size: 24),
                );
              }
              return ImageViewer(
                imageUrl: src,
                isEmoticon: true,
                margin: const EdgeInsets.symmetric(horizontal: 2),
              );
            }

            final urls = PostImageUrls.resolve(src: src);
            if (!shouldShowPostImage(0)) {
              return const SizedBox.shrink();
            }
            return ImageViewer(
              imageUrl: urls.previewUrl,
              fullImageUrl: urls.fullUrl,
              showBorder: true,
              margin: const EdgeInsets.symmetric(vertical: 8),
              deferUntilVisible: widget.deferImages,
            );
          },
        ),
      ],
    );
  }
}
