/// Discuz `forumdisplay` 主题列表排序 / 筛选预设（对齐网页顶栏 +「更多」两轴）。
enum ThreadListSortPreset {
  /// 网页「全部主题」：无额外 filter。
  all,

  /// 网页顶栏「最新」：`filter=lastpost&orderby=lastpost`。
  latest,

  /// 网页「更多 → 排序 → 发帖时间」。
  newest,

  heat,
  hot,
  digest,
  replies,
  views;

  String get label => switch (this) {
        ThreadListSortPreset.all => '全部主题',
        ThreadListSortPreset.latest => '最新',
        ThreadListSortPreset.newest => '发帖时间',
        ThreadListSortPreset.heat => '热门',
        ThreadListSortPreset.hot => '热帖',
        ThreadListSortPreset.digest => '精华',
        ThreadListSortPreset.replies => '回复数',
        ThreadListSortPreset.views => '查看数',
      };

  /// 主 Chip 条预设（不含「更多 → 排序」里的发帖时间 / 回复 / 查看）。
  bool get isPrimaryChip => switch (this) {
        ThreadListSortPreset.all ||
        ThreadListSortPreset.latest ||
        ThreadListSortPreset.heat ||
        ThreadListSortPreset.hot ||
        ThreadListSortPreset.digest =>
          true,
        ThreadListSortPreset.newest ||
        ThreadListSortPreset.replies ||
        ThreadListSortPreset.views =>
          false,
      };
}

class ThreadListTimeOption {
  const ThreadListTimeOption({
    required this.seconds,
    required this.label,
  });

  final int seconds;
  final String label;
}

/// 网页「更多 → 时间」选项（三个月按 Discuz 7948800，非 90*86400）。
const threadListTimeOptions = <ThreadListTimeOption>[
  ThreadListTimeOption(seconds: 0, label: '全部时间'),
  ThreadListTimeOption(seconds: 86400, label: '一天'),
  ThreadListTimeOption(seconds: 172800, label: '两天'),
  ThreadListTimeOption(seconds: 604800, label: '一周'),
  ThreadListTimeOption(seconds: 2592000, label: '一个月'),
  ThreadListTimeOption(seconds: 7948800, label: '三个月'),
];

const threadListPrimaryPresets = <ThreadListSortPreset>[
  ThreadListSortPreset.all,
  ThreadListSortPreset.latest,
  ThreadListSortPreset.heat,
  ThreadListSortPreset.hot,
  ThreadListSortPreset.digest,
];

/// 网页「更多 → 排序」三项。
const threadListMoreSortPresets = <ThreadListSortPreset>[
  ThreadListSortPreset.newest,
  ThreadListSortPreset.replies,
  ThreadListSortPreset.views,
];

/// 版块主题列表的排序 / 时间筛选（会话内状态，不持久化）。
class ThreadListQuery {
  const ThreadListQuery({
    this.preset = ThreadListSortPreset.all,
    this.datelineSeconds = 0,
  });

  static const defaults = ThreadListQuery();

  final ThreadListSortPreset preset;

  /// `0` = 全部时间；否则为 Discuz `dateline` 秒数。
  final int datelineSeconds;

  bool get isDefault =>
      preset == ThreadListSortPreset.all && datelineSeconds <= 0;

  bool get hasTimeFilter => datelineSeconds > 0;

  /// 「更多」Chip 选中：排序落在更多项，或任意时间窗。
  bool get moreChipSelected => !preset.isPrimaryChip || hasTimeFilter;

  String get timeLabel {
    for (final option in threadListTimeOptions) {
      if (option.seconds == datelineSeconds) return option.label;
    }
    return '全部时间';
  }

  ThreadListQuery copyWith({
    ThreadListSortPreset? preset,
    int? datelineSeconds,
  }) {
    return ThreadListQuery(
      preset: preset ?? this.preset,
      datelineSeconds: datelineSeconds ?? this.datelineSeconds,
    );
  }

  /// 组装 `forumdisplay` 查询参数（不含 `fid` / `page` / `tpp`）。
  ///
  /// 组合规则：
  /// 1. 有 [typeId]：始终 `filter=typeid` + `typeid=`；再附加 orderby / digest / dateline。
  /// 2. **发帖时间**（`newest`）：始终 `filter=author&orderby=dateline`；
  ///    时间窗只附加 `dateline=`（按发帖时间截取）。
  /// 3. **回复数 / 查看数**：始终 `filter=reply` + 对应 orderby；时间窗附加 `dateline=`。
  /// 4. **最新**（`latest`）无时间窗：`filter=lastpost&orderby=lastpost`。
  /// 5. 其它预设 + 时间窗：`filter=dateline`（按最后回复截取）+ 预设 extras。
  /// 6. 无时间窗：按预设写完整 filter。
  Map<String, String> toForumDisplayParams({String? typeId}) {
    final trimmedType = typeId == null || typeId.isEmpty ? null : typeId.trim();
    final hasType = trimmedType != null && trimmedType.isNotEmpty;
    final params = <String, String>{};

    if (hasType) {
      params['filter'] = 'typeid';
      params['typeid'] = trimmedType;
      _applyPresetExtras(params, includeFilter: false);
      if (hasTimeFilter) {
        params['dateline'] = datelineSeconds.toString();
      }
      return params;
    }

    // 发帖时间排序：时间窗按「发帖」截取，必须保留 filter=author。
    if (preset == ThreadListSortPreset.newest) {
      params['filter'] = 'author';
      params['orderby'] = 'dateline';
      if (hasTimeFilter) {
        params['dateline'] = datelineSeconds.toString();
      }
      return params;
    }

    // 回复/查看：保留 filter=reply，时间窗附加 dateline（按最后回复截取）。
    if (preset == ThreadListSortPreset.replies ||
        preset == ThreadListSortPreset.views) {
      params['filter'] = 'reply';
      params['orderby'] =
          preset == ThreadListSortPreset.replies ? 'replies' : 'views';
      if (hasTimeFilter) {
        params['dateline'] = datelineSeconds.toString();
      }
      return params;
    }

    if (hasTimeFilter) {
      params['filter'] = 'dateline';
      params['dateline'] = datelineSeconds.toString();
      _applyPresetExtras(params, includeFilter: false);
      if (preset == ThreadListSortPreset.all ||
          preset == ThreadListSortPreset.latest) {
        params['orderby'] = 'lastpost';
      }
      return params;
    }

    _applyPresetExtras(params, includeFilter: true);
    return params;
  }

  void _applyPresetExtras(
    Map<String, String> params, {
    required bool includeFilter,
  }) {
    switch (preset) {
      case ThreadListSortPreset.all:
        break;
      case ThreadListSortPreset.latest:
        if (includeFilter) params['filter'] = 'lastpost';
        params['orderby'] = 'lastpost';
      case ThreadListSortPreset.newest:
        if (includeFilter) params['filter'] = 'author';
        params['orderby'] = 'dateline';
      case ThreadListSortPreset.heat:
        if (includeFilter) params['filter'] = 'heat';
        params['orderby'] = 'heats';
      case ThreadListSortPreset.hot:
        if (includeFilter) params['filter'] = 'hot';
      case ThreadListSortPreset.digest:
        if (includeFilter) params['filter'] = 'digest';
        params['digest'] = '1';
      case ThreadListSortPreset.replies:
        if (includeFilter) params['filter'] = 'reply';
        params['orderby'] = 'replies';
      case ThreadListSortPreset.views:
        if (includeFilter) params['filter'] = 'reply';
        params['orderby'] = 'views';
    }
  }

  @override
  bool operator ==(Object other) {
    return other is ThreadListQuery &&
        other.preset == preset &&
        other.datelineSeconds == datelineSeconds;
  }

  @override
  int get hashCode => Object.hash(preset, datelineSeconds);
}

/// 筛选区收起时的一行摘要。
///
/// 全默认且无分类 → `筛选`；否则用 ` · ` 拼接排序标签、时间、分类名。
String threadListFilterSummary({
  required ThreadListQuery query,
  String? typeName,
}) {
  final trimmedType = typeName?.trim();
  final hasType = trimmedType != null && trimmedType.isNotEmpty;
  if (query.isDefault) {
    if (hasType) return '全部主题 · 全部时间 · $trimmedType';
    return '全部主题 · 全部时间';
  }

  final parts = <String>[query.preset.label];
  if (query.hasTimeFilter) parts.add(query.timeLabel);
  if (hasType) parts.add(trimmedType);
  return parts.join(' · ');
}
