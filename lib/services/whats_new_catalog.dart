import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/whats_new_entry.dart';
import '../utils/semver.dart';
import 'talker.dart';

/// 随包更新说明目录（`rootBundle` 加载，进程内缓存）。
class WhatsNewCatalog {
  WhatsNewCatalog({
    AssetBundle? bundle,
    this.assetPath = defaultAssetPath,
  }) : _bundle = bundle;

  static const defaultAssetPath = 'assets/changelog/whats_new.json';

  final AssetBundle? _bundle;
  final String assetPath;

  List<WhatsNewEntry> _entries = const [];
  var _loaded = false;

  bool get isLoaded => _loaded;

  /// 全量条目（新→旧）。未加载时为空。
  List<WhatsNewEntry> get entries => List.unmodifiable(_entries);

  Future<void> load() async {
    if (_loaded) return;
    try {
      final raw = await (_bundle ?? rootBundle).loadString(assetPath);
      _entries = parseCatalogJson(raw);
    } on Object catch (e) {
      // 可恢复：空目录；坏资产/缺失属预期降级，勿按崩溃打 exception。
      talker.warning('Failed to load whats_new catalog: $e');
      _entries = const [];
    }
    _loaded = true;
  }

  /// 解析 JSON；坏结构抛 [FormatException]。
  static List<WhatsNewEntry> parseCatalogJson(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      throw const FormatException('whats_new root must be an object');
    }
    final list = decoded['entries'];
    if (list is! List) {
      throw const FormatException('entries must be a list');
    }
    final entries = <WhatsNewEntry>[];
    for (final item in list) {
      if (item is! Map) {
        throw const FormatException('entry must be an object');
      }
      entries.add(WhatsNewEntry.fromJson(Map<String, dynamic>.from(item)));
    }
    entries.sort((a, b) => Semver.compare(b.version, a.version));
    return entries;
  }

  /// 筛出 `(seenVersion, currentVersion]` 的条目（新→旧）。
  ///
  /// 非法版本号的条目会被跳过。
  List<WhatsNewEntry> entriesInRange({
    required String seenVersion,
    required String currentVersion,
  }) {
    return filterInRange(
      _entries,
      seenVersion: seenVersion,
      currentVersion: currentVersion,
    );
  }

  /// 纯函数筛选，便于单测。
  static List<WhatsNewEntry> filterInRange(
    List<WhatsNewEntry> entries, {
    required String seenVersion,
    required String currentVersion,
  }) {
    final seen = seenVersion.trim();
    final current = currentVersion.trim();
    if (seen.isEmpty || current.isEmpty) return const [];

    final result = <WhatsNewEntry>[];
    for (final entry in entries) {
      try {
        if (Semver.isGreaterThan(entry.version, seen) &&
            !Semver.isGreaterThan(entry.version, current)) {
          result.add(entry);
        }
      } on FormatException {
        // 跳过无法比较的条目
      }
    }
    return result;
  }
}
