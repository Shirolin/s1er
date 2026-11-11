part of '../compose_screen.dart';

class _ComposeMessageField extends StatelessWidget {
  const _ComposeMessageField({
    required this.controller,
    required this.focusNode,
    required this.hintText,
    required this.onTap,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String hintText;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final hasContent = controller.text.trim().isNotEmpty;
    final focused = focusNode.hasFocus;
    final active = hasContent || focused;
    final desktop = context.isExpandedOrAbove;
    // 桌面 Card 内透明贴合奶油表面；手机保持 Highest 凹槽 / Low 内容态。
    final fillColor = desktop
        ? Colors.transparent
        : (active
            ? scheme.surfaceContainerLow
            : scheme.surfaceContainerHighest);

    return AnimatedContainer(
      duration: S1Motion.short,
      curve: S1Motion.standard,
      color: fillColor,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        maxLines: null,
        expands: true,
        textAlignVertical: TextAlignVertical.top,
        style: textTheme.bodyLarge,
        onTap: onTap,
        // 正文区几乎全屏；空内容时长按会放大 hint，误触极多。选区/粘贴菜单仍可用。
        magnifierConfiguration: TextMagnifierConfiguration.disabled,
        decoration: InputDecoration(
          filled: true,
          fillColor: Colors.transparent,
          hintText: hintText,
          hintStyle: textTheme.bodyLarge?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
          // expands 输入框底边 underline 会横在工具栏上方，看起来像粗分隔线。
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: const EdgeInsets.all(16),
        ),
      ),
    );
  }
}

class _ComposeSubjectLine extends StatefulWidget {
  const _ComposeSubjectLine({required this.subject});

  final String subject;

  @override
  State<_ComposeSubjectLine> createState() => _ComposeSubjectLineState();
}

class _ComposeSubjectLineState extends State<_ComposeSubjectLine> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Material(
      color: scheme.surfaceContainer,
      child: S1InkWell(
        onTap: () => setState(() => _expanded = !_expanded),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  '主题 · ${widget.subject}',
                  maxLines: _expanded ? null : 1,
                  overflow:
                      _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
                  style: textTheme.labelMedium?.copyWith(
                    color:
                        _expanded ? scheme.onSurface : scheme.onSurfaceVariant,
                  ),
                ),
              ),
              Icon(
                _expanded ? Icons.expand_less : Icons.expand_more,
                color: scheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ComposeQuoteBanner extends StatefulWidget {
  const _ComposeQuoteBanner({
    this.post,
    this.displayFloor = 0,
    this.title,
    this.preview,
    required this.onRemove,
    this.loading = false,
    this.error,
  });

  final Post? post;
  final int displayFloor;

  /// 编辑页等：直接给标题/摘要（优先于 [post]）。
  final String? title;
  final String? preview;
  final VoidCallback onRemove;
  final bool loading;
  final String? error;

  @override
  State<_ComposeQuoteBanner> createState() => _ComposeQuoteBannerState();
}

class _ComposeQuoteBannerState extends State<_ComposeQuoteBanner> {
  bool _expanded = false;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _expanded = context.isExpandedOrAbove;
      _initialized = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final post = widget.post;
    final resolvedPreview = widget.preview ??
        (post == null ? '' : QuoteBuilder.previewText(post.message));
    final resolvedTitle = widget.title ??
        (post == null
            ? '引用楼层'
            : widget.displayFloor > 0
                ? '引用 #${widget.displayFloor} 楼 · ${post.author}'
                : '引用 ${post.author}');

    return Material(
      color: scheme.surfaceContainerHigh,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.loading)
            LinearProgressIndicator(
              minHeight: 2,
              color: scheme.primary,
              backgroundColor: scheme.surfaceContainerHighest,
            ),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(width: 3, color: scheme.primary),
                Expanded(
                  child: S1InkWell(
                    onTap: () {
                      setState(() => _expanded = !_expanded);
                    },
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 0, 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  resolvedTitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: textTheme.labelLarge?.copyWith(
                                    color: scheme.onSurface,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              Icon(
                                _expanded
                                    ? Icons.expand_less
                                    : Icons.expand_more,
                                color: scheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 4),
                            ],
                          ),
                          if (_expanded && widget.error != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              widget.error!,
                              style: textTheme.bodySmall?.copyWith(
                                color: scheme.error,
                              ),
                            ),
                          ],
                          if (_expanded && resolvedPreview.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              resolvedPreview,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: '移除引用',
                  onPressed: widget.onRemove,
                  icon: Icon(Icons.close, color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
