part of '../compose_screen.dart';

class _ComposeBottomBar extends StatelessWidget {
  const _ComposeBottomBar({
    required this.busy,
    required this.canSubmit,
    required this.canPreview,
    required this.isSubmitting,
    required this.isUploadingImage,
    required this.characterCount,
    required this.emoticonPanelOpen,
    required this.onPickImage,
    required this.onToggleEmoticon,
    required this.onPreview,
    required this.onSubmit,
    required this.onBbcodeWrap,
    required this.onInsertUrl,
    required this.onWrapColor,
    required this.onInsertCreditHide,
    this.uploadProgressLabel,
    this.submitLabel = '发送',
  });

  final bool busy;
  final bool canSubmit;
  final bool canPreview;
  final bool isSubmitting;
  final bool isUploadingImage;
  final int characterCount;
  final String? uploadProgressLabel;
  final bool emoticonPanelOpen;
  final VoidCallback onPickImage;
  final VoidCallback onToggleEmoticon;
  final VoidCallback onPreview;
  final VoidCallback onSubmit;
  final void Function(String openTag, String closeTag) onBbcodeWrap;
  final VoidCallback onInsertUrl;
  final ValueChanged<String> onWrapColor;
  final VoidCallback onInsertCreditHide;
  final String submitLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final desktop = context.isExpandedOrAbove;
    final imageLabel = uploadProgressLabel ?? (isUploadingImage ? '上传中' : '图片');

    return Material(
      color: desktop ? Colors.transparent : S1BottomBarStyle.background(scheme),
      elevation: 0,
      child: AnimatedPadding(
        duration: S1Motion.rapid,
        curve: S1Motion.standard,
        padding: EdgeInsets.only(bottom: bottomInset),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ComposeBbcodeToolbar(
                busy: busy,
                onWrap: onBbcodeWrap,
                onInsertUrl: onInsertUrl,
                onWrapColor: onWrapColor,
                onInsertCreditHide: onInsertCreditHide,
              ),
              Divider(
                height: 1,
                thickness: 1,
                color: scheme.outlineVariant.withValues(alpha: S1Alpha.half),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
                child: Row(
                  children: [
                    if (desktop) ...[
                      TextButton.icon(
                        onPressed: busy ? null : onToggleEmoticon,
                        icon: Icon(
                          emoticonPanelOpen
                              ? Icons.keyboard_outlined
                              : Icons.emoji_emotions_outlined,
                        ),
                        label: Text(emoticonPanelOpen ? '键盘' : '表情'),
                      ),
                      TextButton.icon(
                        onPressed: busy ? null : onPickImage,
                        icon: isUploadingImage
                            ? SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: scheme.onSurfaceVariant,
                                ),
                              )
                            : const Icon(Icons.image_outlined),
                        label: Text(imageLabel),
                      ),
                    ] else ...[
                      IconButton(
                        tooltip: emoticonPanelOpen ? '键盘' : '表情',
                        onPressed: busy ? null : onToggleEmoticon,
                        icon: Icon(
                          emoticonPanelOpen
                              ? Icons.keyboard_outlined
                              : Icons.emoji_emotions_outlined,
                        ),
                      ),
                      IconButton(
                        tooltip: imageLabel,
                        onPressed: busy ? null : onPickImage,
                        icon: isUploadingImage
                            ? SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: scheme.onSurfaceVariant,
                                ),
                              )
                            : const Icon(Icons.image_outlined),
                      ),
                    ],
                    const Spacer(),
                    if (desktop) ...[
                      Text(
                        '$characterCount 字',
                        style: textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    IconButton(
                      tooltip: '预览',
                      onPressed: canPreview && !busy ? onPreview : null,
                      icon: const Icon(Icons.visibility_outlined),
                    ),
                    FilledButton(
                      onPressed: canSubmit ? onSubmit : null,
                      style: FilledButton.styleFrom(
                        disabledForegroundColor: scheme.onSurface
                            .withValues(alpha: S1Alpha.disabledIcon),
                        disabledBackgroundColor:
                            scheme.onSurface.withValues(alpha: S1Alpha.subtle),
                      ),
                      child: isSubmitting
                          ? Text(
                              '发送中…',
                              maxLines: 1,
                              style: textTheme.labelLarge?.copyWith(
                                color: scheme.onPrimary,
                              ),
                            )
                          : Text(submitLabel, maxLines: 1),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
