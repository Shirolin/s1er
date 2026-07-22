import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/whats_new_entry.dart';
import '../providers/whats_new_provider.dart';
import '../widgets/s1_content_width.dart';
import '../widgets/whats_new_entry_list.dart';

/// 完整更新日志时间线（设置 / Dialog「查看全部」）。
class WhatsNewScreen extends ConsumerStatefulWidget {
  const WhatsNewScreen({super.key});

  @override
  ConsumerState<WhatsNewScreen> createState() => _WhatsNewScreenState();
}

class _WhatsNewScreenState extends ConsumerState<WhatsNewScreen> {
  Future<List<WhatsNewEntry>>? _load;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _load ??= ref.read(whatsNewProvider.notifier).loadAllEntries();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        title: const Text('更新日志'),
      ),
      body: S1ContentWidth(
        child: FutureBuilder<List<WhatsNewEntry>>(
          future: _load,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    '无法加载更新日志',
                    style: textTheme.bodyLarge?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              );
            }
            final entries = snapshot.data;
            if (entries == null || entries.isEmpty) {
              return Center(
                child: Text(
                  '暂无更新说明',
                  style: textTheme.bodyLarge?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              );
            }
            return ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              children: [
                WhatsNewEntryList(entries: entries),
                const SizedBox(height: 24),
              ],
            );
          },
        ),
      ),
    );
  }
}
