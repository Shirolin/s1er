import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/constants.dart';
import '../config/env_config.dart';
import '../models/emoticon_catalog.dart';
import '../providers/settings_provider.dart';
import '../theme/app_theme.dart';
import '../utils/author_color_cache.dart';
import '../utils/bbcode_cache.dart';
import '../utils/bbcode_parser.dart';
import '../utils/post_image_index_counter.dart';
import '../utils/post_image_urls.dart';
import '../utils/internal_navigation.dart';
import '../utils/post_link_resolver.dart';
import '../utils/quote_jump.dart';
import 'emoticon_widget.dart';
import 'force_show_images.dart';
import 'html_clickable_anchor_extension.dart';
import 'image_viewer.dart';
import 'scroll_pointer_gate.dart';
import '../models/thread_destination.dart';
import '../utils/thread_navigation.dart';

final _anchorTag = RegExp(r'<a\s', caseSensitive: false);

T _profiledBbcode<T>(
  String tag,
  T Function() run, {
  String Function(T value)? detail,
}) {
  if (!EnvConfig.bbcodeProfile) return run();
  final sw = Stopwatch()..start();
  final value = run();
  sw.stop();
  final ms = sw.elapsedMicroseconds / 1000;
  final extra = detail?.call(value);
  debugPrint(
    '[bbcode-profile] $tag ${ms.toStringAsFixed(1)}ms'
    '${extra == null || extra.isEmpty ? '' : ' $extra'}',
  );
  return value;
}

int _countAnchors(String html) => _anchorTag.allMatches(html).length;

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
    this.selectable = true,
  });

  final String bbcode;
  final PostImageIndexCounter imageIndexCounter;
  final int quoteDepth;
  final String? currentTid;
  final bool imagesExpanded;
  final VoidCallback? onExpandImages;

  /// 顶层是否包 [SelectionArea]。Dialog / 路由切换首帧易触发
  /// `!debugNeedsLayout`（Flutter #125065），预览等浮层应关。
  final bool selectable;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (bbcode.isEmpty) return const SizedBox.shrink();

    // Top-level only: nested QuoteBlock shares this counter and must continue
    // assigning after the parent's non-quote segments in the same frame.
    if (quoteDepth == 0) {
      imageIndexCounter.reset();
    }

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

    // Expand chip only on the post root — nested quote renderers share the
    // counter and must not emit a second CTA.
    if (quoteDepth == 0 &&
        hiddenCount > 0 &&
        showImages &&
        onExpandImages != null) {
      widgets.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          // 独立 CTA：居中比贴左更易扫读；ExcludeFocus 避免点击抢焦点后
          // ensureVisible 把列表滚到其它楼层。
          child: Center(
            child: ExcludeFocus(
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
          ),
        ),
      );
    }

    final column = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
    // 仅顶层包 SelectionArea，避免引用区内嵌再包一层切断选区。
    if (quoteDepth > 0 || !selectable) return column;
    return SelectionArea(child: column);
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

    final cleanedText = text
        .replaceFirst(
          RegExp(r'^(\s|<br\s*/?>)+', caseSensitive: false),
          '',
        )
        .replaceFirst(
          RegExp(r'(\s|<br\s*/?>)+$', caseSensitive: false),
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
          currentTid: currentTid,
        ),
      );
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
    final html = _profiledBbcode(
      'parse',
      () => BbcodeParser.parse(
        cleanedText,
        imageIndexCounter: imageIndexCounter,
      ),
      detail: (value) =>
          'cache-miss links=${_countAnchors(value)} len=${value.length}',
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
    this.currentTid,
  });

  final String html;
  final bool showImages;
  final int maxImagesPerPost;
  final bool imagesExpanded;
  final PostImageIndexCounter imageIndexCounter;
  final VoidCallback? onExpandImages;
  final bool deferImages;
  final String? currentTid;

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
  late final Key _htmlKey;

  @override
  void initState() {
    super.initState();
    _htmlKey = UniqueKey();
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
      scheme.surface,
      scheme.surfaceContainerHighest,
    );
    if (themeToken != _cachedThemeToken) {
      _cachedThemeToken = themeToken;
      _cachedWidget = null;
    }
    // 仅在真正重建 Html 时打点；memo hit 不打，避免刷屏。
    _cachedWidget ??= _buildHtml(context);
    return ScrollAwareIgnorePointer(child: _cachedWidget!);
  }

  Widget _buildHtml(BuildContext context) {
    final showImages = widget.showImages;
    final maxImagesPerPost = widget.maxImagesPerPost;
    final imagesExpanded = widget.imagesExpanded;

    final scheme = Theme.of(context).colorScheme;
    final html = AuthorColorCache.adapt(
      widget.html,
      scheme,
      _cachedThemeToken ?? 0,
    );
    final profileDetail = 'links=${_countAnchors(html)} len=${html.length}';
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

    final style = {
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
      'blockquote': Style(
        margin: Margins.symmetric(vertical: 8),
        padding: HtmlPaddings.only(left: 12, top: 4, right: 12, bottom: 8),
        display: Display.block,
      ),
      '.quote-depth-1': Style(
        backgroundColor: scheme.surfaceContainer,
        border:
            Border(left: BorderSide(color: scheme.outlineVariant, width: 3)),
      ),
      '.quote-depth-2': Style(
        backgroundColor: scheme.surfaceContainerHigh,
        border: Border(left: BorderSide(color: scheme.primary, width: 3)),
      ),
      '.quote-depth-3': Style(
        backgroundColor: scheme.surfaceContainerHighest,
        border: Border(left: BorderSide(color: scheme.tertiary, width: 3)),
      ),
      'hr': Style(
        border: Border(
          bottom: BorderSide(color: scheme.outlineVariant, width: 0.8),
        ),
        margin: Margins.symmetric(vertical: 12),
      ),
      'ul': Style(padding: HtmlPaddings.only(left: 16)),
      'ol': Style(padding: HtmlPaddings.only(left: 16)),
      'li': Style(margin: Margins.only(bottom: 8)),
    };

    final extensions = <HtmlExtension>[
      const HtmlClickableAnchorExtension(),
      MatcherExtension(
        matcher: (ctx) =>
            ctx.classes.contains('post-image') ||
            ctx.classes.contains('emoticon'),
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
      TagExtension(
        tagsToExtend: {'quote-header'},
        builder: (context) {
          final author = _unescapeHtml(context.attributes['author'] ?? '引用');
          final link = context.attributes['href'];

          final parsedLink = link != null && link.isNotEmpty
              ? QuoteJumpParser.parsePostLink(
                  link,
                  fallbackTid: widget.currentTid,
                )
              : null;

          return Material(
            color: Colors.transparent,
            child: Semantics(
              button: parsedLink != null,
              label: parsedLink != null ? '跳转到引用帖子' : null,
              child: InkWell(
                borderRadius: S1Shape.small,
                onTap: parsedLink != null
                    ? () {
                        final destination = parsedLink.pid != null
                            ? ThreadPost(parsedLink.tid, parsedLink.pid!)
                            : ResumeThread(parsedLink.tid);
                        openInternalLocation(
                          context.buildContext!,
                          ThreadRouteCodec.encodePath(destination),
                        );
                      }
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
                          author,
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
          );
        },
      ),
      if (kIsWeb) ...[
        TagExtension(
          tagsToExtend: {
            'iframe',
            'video',
            'audio',
            'embed',
            'object',
            'input',
            'button',
            'select',
            'textarea',
            'form',
            'option',
          },
          builder: (context) {
            final tag = context.elementName;
            final src =
                context.attributes['src'] ?? context.attributes['data'] ?? '';

            // 媒体类：显示跳转卡片
            if (const {'iframe', 'video', 'audio', 'embed', 'object'}
                .contains(tag)) {
              final isAudio = tag == 'audio';
              final label = isAudio ? '音频' : '视频/嵌入内容';
              final icon = isAudio ? Icons.audiotrack : Icons.video_library;

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  side: BorderSide(color: scheme.outlineVariant, width: 0.8),
                  borderRadius: S1Shape.small,
                ),
                child: ListTile(
                  leading: Icon(icon),
                  title: Text('$label（点击跳转播放/查看）'),
                  subtitle: src.isNotEmpty
                      ? Text(src, maxLines: 1, overflow: TextOverflow.ellipsis)
                      : null,
                  onTap: src.isNotEmpty
                      ? () => launchUrl(
                            Uri.parse(src),
                            mode: LaunchMode.externalApplication,
                          )
                      : null,
                ),
              );
            }

            // 表单输入框与按钮：用 Flutter 原生纯 Widget 模拟，绝对不使用 PlatformView (HtmlElementView)
            if (tag == 'input') {
              final type = context.attributes['type']?.toLowerCase() ?? 'text';
              if (type == 'checkbox' || type == 'radio') {
                return Icon(
                  type == 'checkbox'
                      ? Icons.check_box_outline_blank
                      : Icons.radio_button_off,
                  size: 18,
                  color: scheme.onSurfaceVariant,
                );
              }
              final value = context.attributes['value'] ?? '';
              final placeholder = context.attributes['placeholder'] ?? '';
              return Container(
                margin: const EdgeInsets.symmetric(vertical: 4),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  border: Border.all(color: scheme.outlineVariant),
                  borderRadius: S1Shape.small,
                ),
                child: Text(
                  value.isNotEmpty ? value : placeholder,
                  style: textTheme.bodyMedium?.copyWith(
                    color: value.isNotEmpty
                        ? scheme.onSurface
                        : scheme.onSurfaceVariant
                            .withValues(alpha: S1Alpha.half),
                  ),
                ),
              );
            }

            if (tag == 'button') {
              final text = context.innerHtml.replaceAll(RegExp(r'<[^>]*>'), '');
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: OutlinedButton(
                  onPressed: null, // 只读展示，不提供交互
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                  child: Text(text.isNotEmpty ? text : '按钮'),
                ),
              );
            }

            if (tag == 'textarea') {
              final value =
                  context.innerHtml.replaceAll(RegExp(r'<[^>]*>'), '');
              return Container(
                margin: const EdgeInsets.symmetric(vertical: 4),
                padding: const EdgeInsets.all(8),
                constraints: const BoxConstraints(minHeight: 60),
                decoration: BoxDecoration(
                  border: Border.all(color: scheme.outlineVariant),
                  borderRadius: S1Shape.small,
                ),
                child: Text(
                  value,
                  style: textTheme.bodyMedium,
                ),
              );
            }

            // 其他表单容器/选项标签：只透传内部文本，避免任何外部 platform 干扰
            return Text(
              context.innerHtml.replaceAll(RegExp(r'<[^>]*>'), ''),
              style: textTheme.bodyMedium,
            );
          },
        ),
      ],
    ];

    void onLinkTap(String? url, _, __) {
      if (url == null) return;
      switch (PostLinkResolver.resolve(url)) {
        case InternalPostLink(:final location):
          openInternalLocation(context, location);
        case ExternalPostLink(:final uri):
          unawaited(launchUrl(uri, mode: LaunchMode.externalApplication));
        case InvalidPostLink():
          break;
      }
    }

    // profiling 开启时先量 DOM 解析，再用 fromElement 避免 Html 内再解析一次。
    if (EnvConfig.bbcodeProfile) {
      final documentElement = _profiledBbcode(
        'html-dom',
        () => HtmlParser.parseHTML(html),
        detail: (_) => profileDetail,
      );
      return _HtmlSubtreeProbe(
        detail: profileDetail,
        child: Html.fromElement(
          key: _htmlKey,
          documentElement: documentElement,
          style: style,
          onLinkTap: onLinkTap,
          extensions: extensions,
        ),
      );
    }

    return Html(
      key: _htmlKey,
      data: html,
      style: style,
      onLinkTap: onLinkTap,
      extensions: extensions,
    );
  }
}

/// 估算 Html 子树首次挂载成本（含 prepareTree / buildTree / 本帧 layout）。
/// 同帧多个楼层同时挂载时会互相叠加，慢滑单楼更准。
class _HtmlSubtreeProbe extends StatefulWidget {
  const _HtmlSubtreeProbe({
    required this.detail,
    required this.child,
  });

  final String detail;
  final Widget child;

  @override
  State<_HtmlSubtreeProbe> createState() => _HtmlSubtreeProbeState();
}

class _HtmlSubtreeProbeState extends State<_HtmlSubtreeProbe> {
  final Stopwatch _sw = Stopwatch();
  bool _logged = false;

  @override
  void initState() {
    super.initState();
    _sw.start();
  }

  @override
  Widget build(BuildContext context) {
    if (!_logged) {
      _logged = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_sw.isRunning) return;
        _sw.stop();
        final ms = _sw.elapsedMicroseconds / 1000;
        debugPrint(
          '[bbcode-profile] html-subtree ${ms.toStringAsFixed(1)}ms '
          '${widget.detail}',
        );
      });
    }
    return widget.child;
  }
}
