import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../models/emoticon_catalog.dart';
import '../theme/app_theme.dart';

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
    final scheme = Theme.of(context).colorScheme;

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
              child: _EmoticonThumb(
                primaryUrl: item.pngUrl,
                fallbackUrl: item.gifUrl,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _EmoticonThumb extends StatelessWidget {
  const _EmoticonThumb({
    required this.primaryUrl,
    required this.fallbackUrl,
    required this.color,
  });

  final String primaryUrl;
  final String fallbackUrl;
  final Color color;

  static const double _size = 32;

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return Image.network(
        primaryUrl,
        width: _size,
        height: _size,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => Image.network(
          fallbackUrl,
          width: _size,
          height: _size,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => Icon(
            Icons.broken_image_outlined,
            size: 20,
            color: color,
          ),
        ),
      );
    }

    return CachedNetworkImage(
      imageUrl: primaryUrl,
      width: _size,
      height: _size,
      fit: BoxFit.contain,
      fadeInDuration: Duration.zero,
      fadeOutDuration: Duration.zero,
      errorWidget: (_, __, ___) => CachedNetworkImage(
        imageUrl: fallbackUrl,
        width: _size,
        height: _size,
        fit: BoxFit.contain,
        fadeInDuration: Duration.zero,
        fadeOutDuration: Duration.zero,
        errorWidget: (_, __, ___) => Icon(
          Icons.broken_image_outlined,
          size: 20,
          color: color,
        ),
      ),
    );
  }
}
