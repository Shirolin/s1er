/// Discuz `forumdisplay` 主题列表排序 / 筛选预设（对齐网页顶栏）。
enum ThreadListSortPreset {
  all,
  newest,
  heat,
  hot,
  digest,
  replies,
  views;

  String get label => switch (this) {
        ThreadListSortPreset.all => '默认',
        ThreadListSortPreset.newest => '最新',
        ThreadListSortPreset.heat => '热门',
        ThreadListSortPreset.hot => '热帖',
        ThreadListSortPreset.digest => '精华',
        ThreadListSortPreset.replies => '回复数',
        ThreadListSortPreset.views => '查看数',
      };

  /// 主 Chip 条上的预设（不含「更多」里的回复数 / 查看数）。
  bool get isPrimaryChip => switch (this) {
        ThreadListSortPreset.all ||
        ThreadListSortPreset.newest ||
        ThreadListSortPreset.heat ||
        ThreadListSortPreset.hot ||
        ThreadListSortPreset.digest =>
          true,
        ThreadListSortPreset.replies || ThreadListSortPreset.views => false,
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
  ThreadListSortPreset.newest,
  ThreadListSortPreset.heat,
  ThreadListSortPreset.hot,
  ThreadListSortPreset.digest,
];

const threadListMorePresets = <ThreadListSortPreset>[
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

  /// 「更多」Chip 是否应呈选中态（回复/查看，或任意时间窗）。
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
  /// 2. 无 [typeId] 且有时间窗：`filter=dateline`（占用 filter）；再附加 orderby / digest。
  /// 3. 否则：按预设写完整 filter + 配套参数。
  Map<String, String> toForumDisplayParams({String? typeId}) {
    final trimmedType =
        typeId == null || typeId.isEmpty ? null : typeId.trim();
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

    if (hasTimeFilter) {
      params['filter'] = 'dateline';
      params['dateline'] = datelineSeconds.toString();
      _applyPresetExtras(params, includeFilter: false);
      // 默认 + 时间窗：与网页一致 orderby=lastpost
      if (preset == ThreadListSortPreset.all) {
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
