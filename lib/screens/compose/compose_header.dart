part of '../compose_screen.dart';

class _ComposeCollapsedTitleLine extends StatelessWidget {
  const _ComposeCollapsedTitleLine({
    required this.title,
    required this.onTap,
  });

  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final display = title.trim().isEmpty ? '未填写标题' : title.trim();
    return Material(
      color: scheme.surfaceContainer,
      child: S1InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '主题 · $display',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.labelMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
              Icon(
                Icons.expand_more,
                color: scheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 正文 filled 输入：空态用 Highest 凹槽；有内容 / 聚焦时降到 Low，区分「内容态」。
class _NewThreadHeader extends StatelessWidget {
  const _NewThreadHeader({
    required this.form,
    required this.controller,
    required this.selectedTypeId,
    required this.collapseTitle,
    required this.subjectFocusNode,
    required this.onExpandTitle,
    required this.onTypeChanged,
    required this.onOpenThreadSettings,
  });

  final NewThreadFormInfo? form;
  final TextEditingController controller;
  final String? selectedTypeId;
  final bool collapseTitle;
  final FocusNode subjectFocusNode;
  final VoidCallback onExpandTitle;
  final ValueChanged<String?> onTypeChanged;
  final VoidCallback onOpenThreadSettings;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    if (form == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: LinearProgressIndicator(),
      );
    }
    if (form?.error != null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          form!.error!,
          style: textTheme.bodyMedium?.copyWith(color: scheme.error),
        ),
      );
    }
    final types = form?.threadTypes ?? const <String, String>{};
    final compact = !context.isExpandedOrAbove;
    final typeRequired = form?.typeRequired ?? false;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (collapseTitle)
                _ComposeCollapsedTitleLine(
                  title: controller.text,
                  onTap: onExpandTitle,
                )
              else
                TextField(
                  controller: controller,
                  focusNode: subjectFocusNode,
                  textInputAction: TextInputAction.next,
                  keyboardType: TextInputType.multiline,
                  minLines: 1,
                  maxLines: 3,
                  style: textTheme.titleMedium,
                  decoration:
                      _composeMetaDecoration(context, labelText: '主题标题'),
                ),
              if (types.isNotEmpty) ...[
                SizedBox(height: collapseTitle ? 8 : 12),
                if (compact)
                  _ComposeThreadMetaSummaryRow(
                    summary: _composeThreadMetaSummary(
                      threadTypes: types,
                      readPermissions: const {},
                      selectedTypeId: selectedTypeId,
                      selectedReadPerm: null,
                      typeRequired: typeRequired,
                    ),
                    hasError: _composeThreadMetaSummaryHasError(
                      threadTypes: types,
                      selectedTypeId: selectedTypeId,
                      typeRequired: typeRequired,
                    ),
                    onTap: onOpenThreadSettings,
                  )
                else
                  _ComposeThreadMetaFields(
                    threadTypes: types,
                    readPermissions: const {},
                    selectedTypeId: selectedTypeId,
                    selectedReadPerm: null,
                    allowUncategorized: !typeRequired,
                    onTypeChanged: onTypeChanged,
                    onReadPermChanged: (_) {},
                  ),
              ],
            ],
          ),
        ),
        Divider(
          height: 1,
          thickness: 1,
          color: scheme.outlineVariant.withValues(alpha: S1Alpha.half),
        ),
      ],
    );
  }
}

class _EditPostHeader extends StatelessWidget {
  const _EditPostHeader({
    required this.form,
    required this.controller,
    required this.selectedTypeId,
    required this.selectedReadPerm,
    required this.collapseTitle,
    required this.subjectFocusNode,
    required this.onExpandTitle,
    required this.onTypeChanged,
    required this.onReadPermChanged,
    required this.onOpenThreadSettings,
  });

  final EditPostFormInfo? form;
  final TextEditingController controller;
  final String? selectedTypeId;
  final String? selectedReadPerm;
  final bool collapseTitle;
  final FocusNode subjectFocusNode;
  final VoidCallback onExpandTitle;
  final ValueChanged<String?> onTypeChanged;
  final ValueChanged<String?> onReadPermChanged;
  final VoidCallback onOpenThreadSettings;

  @override
  Widget build(BuildContext context) {
    final form = this.form;
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    if (form?.error != null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          form!.error!,
          style: textTheme.bodyMedium?.copyWith(color: scheme.error),
        ),
      );
    }
    if (form == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: LinearProgressIndicator(),
      );
    }
    final compact = !context.isExpandedOrAbove;
    final hasSettings =
        form.threadTypes.isNotEmpty || form.readPermissions.isNotEmpty;
    if (!form.isFirst && !hasSettings) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (form.isFirst) ...[
                if (collapseTitle)
                  _ComposeCollapsedTitleLine(
                    title: controller.text,
                    onTap: onExpandTitle,
                  )
                else
                  TextField(
                    controller: controller,
                    focusNode: subjectFocusNode,
                    textInputAction: TextInputAction.next,
                    keyboardType: TextInputType.multiline,
                    minLines: 1,
                    maxLines: 3,
                    style: textTheme.titleMedium,
                    decoration:
                        _composeMetaDecoration(context, labelText: '主题标题'),
                  ),
              ],
              if (hasSettings) ...[
                if (form.isFirst) SizedBox(height: collapseTitle ? 8 : 12),
                if (compact)
                  _ComposeThreadMetaSummaryRow(
                    summary: _composeThreadMetaSummary(
                      threadTypes: form.threadTypes,
                      readPermissions: form.readPermissions,
                      selectedTypeId:
                          form.threadTypes.containsKey(selectedTypeId)
                              ? selectedTypeId
                              : null,
                      selectedReadPerm: form.readPermissions.containsKey(
                        selectedReadPerm,
                      )
                          ? selectedReadPerm
                          : null,
                      typeRequired: false,
                    ),
                    hasError: false,
                    onTap: onOpenThreadSettings,
                  )
                else ...[
                  if (form.threadTypes.isNotEmpty)
                    _ComposeThreadMetaFields(
                      threadTypes: form.threadTypes,
                      readPermissions: form.readPermissions,
                      selectedTypeId:
                          form.threadTypes.containsKey(selectedTypeId)
                              ? selectedTypeId
                              : null,
                      selectedReadPerm: form.readPermissions.containsKey(
                        selectedReadPerm,
                      )
                          ? selectedReadPerm
                          : null,
                      allowUncategorized: true,
                      onTypeChanged: onTypeChanged,
                      onReadPermChanged: onReadPermChanged,
                    ),
                ],
              ],
            ],
          ),
        ),
        Divider(
          height: 1,
          thickness: 1,
          color: scheme.outlineVariant.withValues(alpha: S1Alpha.half),
        ),
      ],
    );
  }
}

class _EditPostStatus extends StatelessWidget {
  const _EditPostStatus({
    required this.message,
    required this.actionLabel,
    required this.onPressed,
  });

  final String message;
  final String actionLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Material(
      color: scheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
        child: Row(
          children: [
            Expanded(
              child: Text(
                message,
                style: textTheme.bodySmall?.copyWith(
                  color: scheme.onErrorContainer,
                ),
              ),
            ),
            TextButton(
              onPressed: onPressed,
              child: Text(
                actionLabel,
                style: textTheme.labelLarge?.copyWith(
                  color: scheme.onErrorContainer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
