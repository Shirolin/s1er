import 'package:flutter/material.dart';

import '../models/emoticon_catalog.dart';
import '../theme/app_theme.dart';
import '../theme/s1_haptics.dart';
import 'emoticon_widget.dart';

/// 回复页表情面板：键盘高度的 input accessory（与底部操作栏一体），
/// 不是 modal / docked bottom sheet。
///
/// 亮色不用 [ColorScheme.secondaryContainer] 铺格子（易整片发紫）；
/// 面板 / 单元格走中性 surface 色阶，对齐 M3 tonal。
class ComposeEmoticonPanel extends StatefulWidget {
  const ComposeEmoticonPanel({
    super.key,
    required this.onSelect,
    this.recent = const [],
  });

  final ValueChanged<String> onSelect;
  final List<String> recent;

  @override
  State<ComposeEmoticonPanel> createState() => _ComposeEmoticonPanelState();
}

class _ComposeEmoticonPanelState extends State<ComposeEmoticonPanel>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: EmoticonCatalog.packs.length,
      vsync: this,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  double _panelHeight(BuildContext context) {
    final h = MediaQuery.sizeOf(context).height;
    return (h * 0.4).clamp(260.0, 320.0);
  }

  void _pick(String entity) {
    S1Haptics.selection();
    widget.onSelect(entity);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final recentItems = <EmoticonItem>[
      for (final code in widget.recent)
        if (EmoticonCatalog.findByCode(code) case final item?) item,
    ];
    // 与正文写作区同档，避免亮色下整块 secondary 色块。
    final panelColor = scheme.brightness == Brightness.light
        ? scheme.surfaceContainerLow
        : scheme.surfaceContainerHigh;
    final cellColor = scheme.brightness == Brightness.light
        ? scheme.surfaceContainerHighest
        : scheme.surfaceContainerHighest;

    return Material(
      color: panelColor,
      elevation: 0,
      child: SizedBox(
        height: _panelHeight(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Divider(
              height: 1,
              thickness: 1,
              color: scheme.outlineVariant.withValues(alpha: S1Alpha.half),
            ),
            if (recentItems.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                child: Text(
                  '最近',
                  style: textTheme.labelMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
              SizedBox(
                height: 48,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  scrollDirection: Axis.horizontal,
                  itemCount: recentItems.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 4),
                  itemBuilder: (context, index) {
                    final item = recentItems[index];
                    return Material(
                      color: cellColor,
                      borderRadius: S1Shape.small,
                      child: InkWell(
                        onTap: () => _pick(item.entity),
                        borderRadius: S1Shape.small,
                        child: Tooltip(
                          message: item.entity,
                          child: Padding(
                            padding: const EdgeInsets.all(6),
                            child: EmoticonImage(item: item, size: 36),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
            TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelStyle: textTheme.labelLarge,
              unselectedLabelStyle: textTheme.labelLarge,
              labelColor: scheme.primary,
              unselectedLabelColor: scheme.onSurfaceVariant,
              indicatorColor: scheme.primary,
              indicatorSize: TabBarIndicatorSize.label,
              dividerColor:
                  scheme.outlineVariant.withValues(alpha: S1Alpha.half),
              tabs: [
                for (final pack in EmoticonCatalog.packs) Tab(text: pack.title),
              ],
            ),
            Expanded(
              child: ColoredBox(
                color: panelColor,
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    for (final pack in EmoticonCatalog.packs)
                      _EmoticonGrid(
                        pack: pack,
                        cellColor: cellColor,
                        onSelect: _pick,
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmoticonGrid extends StatelessWidget {
  const _EmoticonGrid({
    required this.pack,
    required this.cellColor,
    required this.onSelect,
  });

  final EmoticonPack pack;
  final Color cellColor;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final items = EmoticonCatalog.itemsFor(pack);

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 6,
        mainAxisSpacing: 6,
        crossAxisSpacing: 6,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return Material(
          color: cellColor,
          borderRadius: S1Shape.small,
          child: InkWell(
            onTap: () => onSelect(item.entity),
            borderRadius: S1Shape.small,
            child: Tooltip(
              message: item.entity,
              child: Center(
                child: EmoticonImage(item: item, size: 40),
              ),
            ),
          ),
        );
      },
    );
  }
}
