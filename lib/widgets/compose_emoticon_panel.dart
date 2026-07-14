import 'package:flutter/material.dart';

import '../models/emoticon_catalog.dart';
import '../theme/app_theme.dart';
import 'emoticon_widget.dart';

/// 回复页表情面板：分类 Tab + 网格，点击回传实体码（如 `[f:001]`）。
class ComposeEmoticonPanel extends StatefulWidget {
  const ComposeEmoticonPanel({
    super.key,
    required this.onSelect,
  });

  final ValueChanged<String> onSelect;

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

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Material(
      color: scheme.surfaceContainer,
      child: SizedBox(
        height: 248,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelStyle: textTheme.labelLarge,
              unselectedLabelStyle: textTheme.labelLarge,
              tabs: [
                for (final pack in EmoticonCatalog.packs)
                  Tab(text: pack.title),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  for (final pack in EmoticonCatalog.packs)
                    _EmoticonGrid(
                      pack: pack,
                      onSelect: widget.onSelect,
                    ),
                ],
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
    required this.onSelect,
  });

  final EmoticonPack pack;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final items = EmoticonCatalog.itemsFor(pack);

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        mainAxisSpacing: 4,
        crossAxisSpacing: 4,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return InkWell(
          onTap: () => onSelect(item.entity),
          borderRadius: S1Shape.small,
          child: Tooltip(
            message: item.entity,
            child: Center(
              child: EmoticonImage(item: item, size: 32),
            ),
          ),
        );
      },
    );
  }
}
