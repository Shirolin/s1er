part of '../compose_screen.dart';

/// 发帖元信息（标题 / 分类 / 权限）共用：filled 色阶，无硬描边。
InputDecorationTheme _composeMetaInputTheme(ColorScheme scheme) {
  return InputDecorationTheme(
    filled: true,
    fillColor: scheme.surfaceContainerHigh,
    border: const OutlineInputBorder(
      borderRadius: S1Shape.small,
      borderSide: BorderSide.none,
    ),
    enabledBorder: const OutlineInputBorder(
      borderRadius: S1Shape.small,
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: S1Shape.small,
      borderSide: BorderSide(color: scheme.primary, width: 2),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
  );
}

InputDecoration _composeMetaDecoration(
  BuildContext context, {
  required String labelText,
}) {
  final scheme = Theme.of(context).colorScheme;
  final theme = _composeMetaInputTheme(scheme);
  return InputDecoration(
    labelText: labelText,
    filled: theme.filled,
    fillColor: theme.fillColor,
    border: theme.border,
    enabledBorder: theme.enabledBorder,
    focusedBorder: theme.focusedBorder,
    contentPadding: theme.contentPadding,
  );
}

/// M3 [DropdownMenu]：浮层菜单（圆角 + 低 elevation），替代割裂的 [DropdownButtonFormField]。
class _ComposeDropdownMenu extends StatelessWidget {
  const _ComposeDropdownMenu({
    required this.label,
    required this.entries,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final List<({String value, String label})> entries;
  final String? selected;
  final ValueChanged<String?> onSelected;

  static const _noneValue = '';

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    String effective;
    if (selected != null && entries.any((e) => e.value == selected)) {
      effective = selected!;
    } else if (entries.any((e) => e.value == _noneValue)) {
      effective = _noneValue;
    } else if (entries.isNotEmpty) {
      effective = entries.first.value;
    } else {
      effective = _noneValue;
    }

    return DropdownMenu<String>(
      key: ValueKey('$label-$effective'),
      initialSelection: effective,
      label: Text(label),
      expandedInsets: EdgeInsets.zero,
      inputDecorationTheme: _composeMetaInputTheme(scheme),
      menuStyle: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(scheme.surfaceContainer),
        elevation: const WidgetStatePropertyAll(3),
        shadowColor: WidgetStatePropertyAll(scheme.shadow),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        shape: const WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: S1Shape.small),
        ),
        maximumSize: const WidgetStatePropertyAll(Size(double.infinity, 320)),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(vertical: 8),
        ),
      ),
      dropdownMenuEntries: [
        for (final entry in entries)
          DropdownMenuEntry<String>(
            value: entry.value,
            label: entry.label,
            style: ButtonStyle(
              textStyle: WidgetStatePropertyAll(
                Theme.of(context).textTheme.bodyLarge,
              ),
              maximumSize: const WidgetStatePropertyAll(
                Size(double.infinity, double.infinity),
              ),
            ),
          ),
      ],
      onSelected: (value) {
        if (value == null || value == _noneValue) {
          onSelected(null);
        } else {
          onSelected(value);
        }
      },
    );
  }
}

String _composeThreadMetaSummary({
  required Map<String, String> threadTypes,
  required Map<String, String> readPermissions,
  required String? selectedTypeId,
  required String? selectedReadPerm,
  required bool typeRequired,
}) {
  final parts = <String>[];
  if (threadTypes.isNotEmpty) {
    if (typeRequired &&
        (selectedTypeId == null ||
            selectedTypeId.isEmpty ||
            !threadTypes.containsKey(selectedTypeId))) {
      parts.add('请选择分类');
    } else if (selectedTypeId != null &&
        selectedTypeId.isNotEmpty &&
        threadTypes.containsKey(selectedTypeId)) {
      parts.add(threadTypes[selectedTypeId]!);
    } else {
      parts.add('不分类');
    }
  }
  if (readPermissions.isNotEmpty) {
    final perm = selectedReadPerm;
    if (perm == null || perm.isEmpty || perm == '0') {
      parts.add('权限不限');
    } else {
      parts.add('阅读权限 ${readPermissions[perm] ?? perm}');
    }
  }
  if (parts.isEmpty) return '';
  return '主题设置 · ${parts.join(' · ')}';
}

bool _composeThreadMetaSummaryHasError({
  required Map<String, String> threadTypes,
  required String? selectedTypeId,
  required bool typeRequired,
}) {
  return threadTypes.isNotEmpty &&
      typeRequired &&
      (selectedTypeId == null ||
          selectedTypeId.isEmpty ||
          !threadTypes.containsKey(selectedTypeId));
}

class _ComposeThreadMetaFields extends StatelessWidget {
  const _ComposeThreadMetaFields({
    required this.threadTypes,
    required this.readPermissions,
    required this.selectedTypeId,
    required this.selectedReadPerm,
    required this.allowUncategorized,
    required this.onTypeChanged,
    required this.onReadPermChanged,
  });

  final Map<String, String> threadTypes;
  final Map<String, String> readPermissions;
  final String? selectedTypeId;
  final String? selectedReadPerm;
  final bool allowUncategorized;
  final ValueChanged<String?> onTypeChanged;
  final ValueChanged<String?> onReadPermChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (threadTypes.isNotEmpty)
          _ComposeDropdownMenu(
            label: '主题分类',
            selected:
                threadTypes.containsKey(selectedTypeId) ? selectedTypeId : null,
            onSelected: onTypeChanged,
            entries: [
              if (allowUncategorized) (value: '', label: '不分类'),
              for (final entry in threadTypes.entries)
                (value: entry.key, label: entry.value),
            ],
          ),
        if (readPermissions.isNotEmpty) ...[
          if (threadTypes.isNotEmpty) const SizedBox(height: 12),
          _ComposeDropdownMenu(
            label: '阅读权限',
            selected: readPermissions.containsKey(selectedReadPerm)
                ? selectedReadPerm
                : null,
            onSelected: onReadPermChanged,
            entries: [
              for (final entry in readPermissions.entries)
                (value: entry.key, label: entry.value),
            ],
          ),
        ],
      ],
    );
  }
}

class _ComposeThreadMetaSummaryRow extends StatelessWidget {
  const _ComposeThreadMetaSummaryRow({
    required this.summary,
    required this.hasError,
    required this.onTap,
  });

  final String summary;
  final bool hasError;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return S1InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
        child: Row(
          children: [
            Expanded(
              child: Text(
                summary,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.labelMedium?.copyWith(
                  color: hasError ? scheme.error : scheme.onSurfaceVariant,
                ),
              ),
            ),
            Icon(
              Icons.settings_outlined,
              size: 18,
              color: scheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}
