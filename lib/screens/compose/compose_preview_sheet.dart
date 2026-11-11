part of '../compose_screen.dart';

/// 发帖 / 回复预览：Dialog 画布 + 一帖 Card（对齐读帖 surface 层级）。
/// 主题在卡上方；卡内只预览楼层正文。
class _ComposePreviewSheet extends StatelessWidget {
  const _ComposePreviewSheet({
    required this.subject,
    required this.isNewThread,
    required this.isEditing,
    required this.quoteInfo,
    required this.previewBbcode,
    required this.tid,
    required this.authorName,
    this.authorAvatar,
    this.attachPreviewLimited = false,
    required this.canSubmit,
    required this.submitLabel,
  });

  final String? subject;
  final bool isNewThread;
  final bool isEditing;
  final QuoteInfo? quoteInfo;
  final String previewBbcode;
  final String? tid;
  final String authorName;
  final String? authorAvatar;

  /// 仍有未解析的 `[attachimg]`，预览里可能显示附件码。
  final bool attachPreviewLimited;
  final bool canSubmit;
  final String submitLabel;

  String get _floorLabel {
    if (isEditing) return '编辑';
    if (isNewThread) return '#1';
    return '回复';
  }

  /// 回复已有「即将回复」副文案，不再叠一颗「回复」Chip；新主题 / 编辑保留楼层标记。
  bool get _showFloorMark => isNewThread || isEditing;

  String get _metaLabel {
    if (isEditing) return '编辑后效果';
    if (isNewThread) return '即将发布';
    return '即将回复';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final desktop = context.isExpandedOrAbove;
    final imageIndexCounter = PostImageIndexCounter();
    final letter = authorName.isNotEmpty ? authorName[0] : '?';
    // 主题始终在卡上方作上下文；卡内只预览楼层正文（含签名）。
    final showSubjectAbove = subject != null;

    final postCard = Card(
      elevation: 0,
      color: S1Surface.card(scheme),
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: S1Shape.cardShape,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                WebAvatar(
                  url: authorAvatar,
                  radius: 20,
                  fallbackLetter: letter,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        authorName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        _metaLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_showFloorMark)
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: scheme.secondaryContainer,
                      borderRadius: S1Shape.extraSmall,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      child: CompactLabel.text(
                        _floorLabel,
                        style: CompactLabel.style(
                          context,
                          base: textTheme.labelSmall,
                          color: scheme.onSecondaryContainer,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            Divider(height: 16, color: scheme.outlineVariant),
            if (quoteInfo != null)
              BbcodeRenderer(
                bbcode: '[quote]${EditPostMessageParts(
                      leadingQuote: quoteInfo!.noticeTrimStr,
                      body: '',
                    ).quoteInner ?? quoteInfo!.noticeTrimStr}[/quote]',
                imageIndexCounter: imageIndexCounter,
                currentTid: tid,
                selectable: false,
              ),
            BbcodeRenderer(
              bbcode: previewBbcode.isEmpty ? '（无内容）' : previewBbcode,
              imageIndexCounter: imageIndexCounter,
              // Dialog 打开动画首帧 SelectionArea 会 assert !debugNeedsLayout。
              selectable: false,
            ),
          ],
        ),
      ),
    );

    return S1AdaptiveSheetScaffold(
      title: '预览',
      scrollable: true,
      maxHeightFactor: desktop ? 0.78 : 0.72,
      footer: S1AdaptiveSheetFooter(
        primaryLabel: submitLabel,
        onPrimary: canSubmit ? () => Navigator.of(context).pop(true) : null,
        primaryEnabled: canSubmit,
        secondaryLabel: desktop ? '关闭' : null,
        onSecondary: desktop ? () => Navigator.of(context).maybePop() : null,
      ),
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (showSubjectAbove) ...[
              Text(
                isNewThread ? subject! : '主题 · $subject',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style:
                    (isNewThread ? textTheme.titleMedium : textTheme.labelLarge)
                        ?.copyWith(
                  color:
                      isNewThread ? scheme.onSurface : scheme.onSurfaceVariant,
                  fontWeight: isNewThread ? FontWeight.w600 : null,
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (attachPreviewLimited) ...[
              Text(
                '部分论坛附件图暂无地址，预览可能显示附件码；保存后仍会按原附件提交。',
                style: textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
            ],
            postCard,
          ],
        ),
      ],
    );
  }
}
