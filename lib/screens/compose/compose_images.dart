part of '../compose_screen.dart';

class _ComposeMediaPreviewHint extends StatelessWidget {
  const _ComposeMediaPreviewHint();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Material(
      color: scheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        child: Text(
          '正文中的 ⟦图N⟧ 可挪动以调整排版；无缩略图的论坛附件仍会保存。',
          style: textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _ComposeImageStrip extends StatefulWidget {
  const _ComposeImageStrip({
    required this.images,
    required this.onRemove,
  });

  final List<_ComposeUploadedImage> images;
  final ValueChanged<_ComposeUploadedImage> onRemove;

  @override
  State<_ComposeImageStrip> createState() => _ComposeImageStripState();
}

class _ComposeImageStripState extends State<_ComposeImageStrip> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final maxLabelWidth =
        (MediaQuery.sizeOf(context).width * 0.4).clamp(88.0, 120.0);

    return Material(
      color: scheme.surfaceContainer,
      child: SizedBox(
        height: 56,
        child: ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(
            dragDevices: {
              PointerDeviceKind.touch,
              PointerDeviceKind.mouse,
              PointerDeviceKind.trackpad,
            },
          ),
          child: Scrollbar(
            controller: _scrollController,
            thumbVisibility: false,
            child: ListView.separated(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
              scrollDirection: Axis.horizontal,
              itemCount: widget.images.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final image = widget.images[index];
                return Tooltip(
                  message: image.label,
                  child: InputChip(
                    mouseCursor: S1MouseCursors.clickable,
                    avatar: _ComposeImageChipAvatar(image: image),
                    label: SizedBox(
                      width: maxLabelWidth,
                      child: Text(
                        displayLabelForIndex(
                          (image.slot != null && image.slot! > 0)
                              ? image.slot! - 1
                              : index,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.labelMedium,
                      ),
                    ),
                    onDeleted: () => widget.onRemove(image),
                    deleteIcon: Icon(
                      Icons.close,
                      size: 18,
                      color: scheme.onSecondaryContainer,
                    ),
                    backgroundColor: scheme.secondaryContainer,
                    side: BorderSide.none,
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// Chip 头像：有 URL 显示缩略图，否则按附件类型给图标。
class _ComposeImageChipAvatar extends StatelessWidget {
  const _ComposeImageChipAvatar({required this.image});

  final _ComposeUploadedImage image;

  static const double _size = 24;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final iconColor = scheme.onSecondaryContainer;
    if (!image.hasThumb) {
      return Icon(
        image.isForumAttach
            ? Icons.attach_file
            : (image.isAttachimg
                ? Icons.image_not_supported_outlined
                : Icons.image_outlined),
        size: 18,
        color: iconColor,
      );
    }

    final url = platformImageUrl(image.previewUrl!.trim(), isWeb: kIsWeb);
    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: url,
        cacheManager: s1ImageCacheManager,
        width: _size,
        height: _size,
        fit: BoxFit.cover,
        fadeInDuration: Duration.zero,
        fadeOutDuration: Duration.zero,
        placeholder: (_, __) => Icon(
          Icons.image_outlined,
          size: 18,
          color: iconColor,
        ),
        errorWidget: (_, __, ___) => Icon(
          Icons.broken_image_outlined,
          size: 18,
          color: iconColor,
        ),
      ),
    );
  }
}

class _ComposeImageUploadOptions extends StatelessWidget {
  const _ComposeImageUploadOptions({
    required this.expanded,
    required this.source,
    required this.useOriginal,
    required this.enabled,
    required this.onExpandedChanged,
    required this.onSourceChanged,
    required this.onOriginalChanged,
  });

  final bool expanded;
  final ComposeImageUploadSource source;
  final bool useOriginal;
  final bool enabled;
  final ValueChanged<bool> onExpandedChanged;
  final ValueChanged<ComposeImageUploadSource> onSourceChanged;
  final ValueChanged<bool> onOriginalChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final sourceLabel = source == ComposeImageUploadSource.forum ? '论坛' : '外链';
    final qualityLabel = useOriginal ? '原图' : '压缩';
    final summary = '图片：$sourceLabel · $qualityLabel';

    return Material(
      color: Colors.transparent,
      elevation: 0,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          S1InkWell(
            onTap: enabled ? () => onExpandedChanged(!expanded) : null,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      summary,
                      style: textTheme.labelMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.tune,
                    size: 18,
                    color: scheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '论坛更稳；外链不占论坛附件额度',
                    style: textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<ComposeImageUploadSource>(
                    segments: const [
                      ButtonSegment(
                        value: ComposeImageUploadSource.forum,
                        label: Text('论坛'),
                      ),
                      ButtonSegment(
                        value: ComposeImageUploadSource.external,
                        label: Text('外链'),
                      ),
                    ],
                    selected: {source},
                    onSelectionChanged: enabled
                        ? (next) {
                            if (next.isEmpty) return;
                            onSourceChanged(next.first);
                          }
                        : null,
                    showSelectedIcon: false,
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('原图上传', style: textTheme.bodyMedium),
                    subtitle: Text(
                      '关闭时最长边约 2000px',
                      style: textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    value: useOriginal,
                    onChanged: enabled ? onOriginalChanged : null,
                  ),
                ],
              ),
            ),
            crossFadeState:
                expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: S1Motion.medium,
          ),
        ],
      ),
    );
  }
}
