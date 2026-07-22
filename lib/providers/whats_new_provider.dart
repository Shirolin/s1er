import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/whats_new_entry.dart';
import '../services/settings_store.dart';
import '../services/talker.dart';
import '../services/whats_new_catalog.dart';
import '../utils/whats_new_store.dart';
import 'settings_provider.dart';
import 'talker_provider.dart';
import 'update_check_provider.dart';

class WhatsNewState {
  const WhatsNewState({
    this.autoCheckStarted = false,
    this.pendingEntries,
  });

  final bool autoCheckStarted;

  /// 待展示的升级说明（由 [WhatsNewPromptHost] 消费后 clear）。
  final List<WhatsNewEntry>? pendingEntries;

  WhatsNewState copyWith({
    bool? autoCheckStarted,
    List<WhatsNewEntry>? pendingEntries,
    bool clearPendingEntries = false,
  }) {
    return WhatsNewState(
      autoCheckStarted: autoCheckStarted ?? this.autoCheckStarted,
      pendingEntries:
          clearPendingEntries ? null : (pendingEntries ?? this.pendingEntries),
    );
  }
}

final whatsNewCatalogProvider = Provider<WhatsNewCatalog>((ref) {
  return WhatsNewCatalog();
});

class WhatsNewNotifier extends Notifier<WhatsNewState> {
  @override
  WhatsNewState build() => const WhatsNewState();

  SettingsStore? _tryStore() {
    try {
      return ref.read(settingsStoreProvider);
    } on Object {
      return null;
    }
  }

  WhatsNewCatalog get _catalog => ref.read(whatsNewCatalogProvider);

  /// 冷启动：延迟后判定；升级 Dialog 优先，有 pending 时由 Host 等待。
  Future<void> runStartupCheck({
    Duration delay = WhatsNewStore.startupDelay,
  }) async {
    if (state.autoCheckStarted) return;
    state = state.copyWith(autoCheckStarted: true);

    if (delay > Duration.zero) {
      await Future<void>.delayed(delay);
    }
    if (!ref.mounted) return;

    try {
      await _waitForUpdateStartupSettled();
      if (!ref.mounted) return;

      final info = await ref.read(packageInfoProvider.future);
      if (!ref.mounted) return;
      final current = info.version.trim();
      final store = _tryStore();
      final seen = WhatsNewStore.seenVersion(store);

      switch (decideWhatsNew(seenVersion: seen, currentVersion: current)) {
        case WhatsNewDecision.none:
          return;
        case WhatsNewDecision.markSeenSilent:
          WhatsNewStore.setSeenVersion(store, current);
          return;
        case WhatsNewDecision.showPrompt:
          await _catalog.load();
          if (!ref.mounted) return;
          final entries = _catalog.entriesInRange(
            seenVersion: seen!,
            currentVersion: current,
          );
          if (entries.isEmpty) {
            WhatsNewStore.setSeenVersion(store, current);
            return;
          }
          state = state.copyWith(pendingEntries: entries);
      }
    } on Object catch (e, st) {
      talker.handle(e, st, 'Startup whats-new check failed');
    }
  }

  /// 等待升级冷启动检查结束（最长约 2 分钟）；弹窗互斥由 Host 处理。
  Future<void> _waitForUpdateStartupSettled() async {
    const poll = Duration(milliseconds: 200);
    const maxWait = Duration(minutes: 2);
    final deadline = DateTime.now().add(maxWait);

    while (ref.mounted && DateTime.now().isBefore(deadline)) {
      if (ref.read(updateCheckProvider).startupSettled) {
        return;
      }
      await Future<void>.delayed(poll);
    }
  }

  void clearPendingEntries() {
    state = state.copyWith(clearPendingEntries: true);
  }

  /// 测试用：直接写入待展示条目。
  @visibleForTesting
  void debugSetPendingEntries(List<WhatsNewEntry> entries) {
    state = state.copyWith(pendingEntries: entries);
  }

  /// Dialog 关闭或「查看全部」后标记当前版本已读。
  Future<void> markSeenCurrent() async {
    try {
      final info = await ref.read(packageInfoProvider.future);
      if (!ref.mounted) return;
      WhatsNewStore.setSeenVersion(_tryStore(), info.version);
    } on Object catch (e, st) {
      talker.handle(e, st, 'markSeenCurrent failed');
    }
  }

  /// 设置页等：确保 catalog 已加载。
  Future<List<WhatsNewEntry>> loadAllEntries() async {
    await _catalog.load();
    return _catalog.entries;
  }
}

final whatsNewProvider =
    NotifierProvider<WhatsNewNotifier, WhatsNewState>(WhatsNewNotifier.new);

/// 在应用根 [ref.watch]，冷启动延迟触发 What's New 检查。
final whatsNewCoordinatorProvider = Provider<void>((ref) {
  scheduleMicrotask(() {
    if (!ref.mounted) return;
    unawaited(ref.read(whatsNewProvider.notifier).runStartupCheck());
  });
});
