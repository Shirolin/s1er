/// Discuz `search.php?mod=forum` 高级搜索参数。
enum ForumSearchFilter {
  all('all'),
  digest('digest'),
  top('top');

  const ForumSearchFilter(this.value);

  final String value;

  String get label => switch (this) {
        ForumSearchFilter.all => '全部主题',
        ForumSearchFilter.digest => '精华主题',
        ForumSearchFilter.top => '置顶主题',
      };
}

/// 特殊主题类型（`special[]`）。
enum ForumSearchSpecial {
  poll(1, '投票主题'),
  trade(2, '商品主题'),
  reward(3, '悬赏主题'),
  activity(4, '活动主题'),
  debate(5, '辩论主题');

  const ForumSearchSpecial(this.value, this.label);

  final int value;
  final String label;
}

class ForumSearchTimeOption {
  const ForumSearchTimeOption({
    required this.seconds,
    required this.label,
  });

  final int seconds;
  final String label;
}

class ForumSearchOrderOption {
  const ForumSearchOrderOption({
    required this.value,
    required this.label,
  });

  final String value;
  final String label;
}

const forumSearchTimeOptions = <ForumSearchTimeOption>[
  ForumSearchTimeOption(seconds: 0, label: '全部时间'),
  ForumSearchTimeOption(seconds: 86400, label: '1 天'),
  ForumSearchTimeOption(seconds: 172800, label: '2 天'),
  ForumSearchTimeOption(seconds: 604800, label: '1 周'),
  ForumSearchTimeOption(seconds: 2592000, label: '1 个月'),
  ForumSearchTimeOption(seconds: 7776000, label: '3 个月'),
  ForumSearchTimeOption(seconds: 15552000, label: '6 个月'),
  ForumSearchTimeOption(seconds: 31536000, label: '1 年'),
];

const forumSearchDefaultOrderOptions = <ForumSearchOrderOption>[
  ForumSearchOrderOption(value: 'lastpost', label: '回复时间'),
  ForumSearchOrderOption(value: 'dateline', label: '发布时间'),
  ForumSearchOrderOption(value: 'replies', label: '回复数量'),
  ForumSearchOrderOption(value: 'views', label: '浏览次数'),
];

const forumSearchTradeOrderOptions = <ForumSearchOrderOption>[
  ForumSearchOrderOption(value: 'dateline', label: '发布时间'),
  ForumSearchOrderOption(value: 'price', label: '商品价格'),
  ForumSearchOrderOption(value: 'expiration', label: '剩余时间'),
];

class ForumSearchQuery {
  const ForumSearchQuery({
    this.keyword = '',
    this.author = '',
    this.filter = ForumSearchFilter.all,
    this.specials = const {},
    this.srchfromSeconds = 0,
    this.before = false,
    this.orderby = 'lastpost',
    this.ascending = false,
    this.forumIds = const {},
  });

  static const empty = ForumSearchQuery();

  static const maxTextLength = 40;

  final String keyword;
  final String author;
  final ForumSearchFilter filter;
  final Set<int> specials;
  final int srchfromSeconds;
  final bool before;

  /// `lastpost` | `dateline` | `replies` | `views` | `price` | `expiration`
  final String orderby;
  final bool ascending;
  final Set<String> forumIds;

  String get trimmedKeyword => keyword.trim();
  String get trimmedAuthor => author.trim();

  bool get hasTradeSpecial => specials.contains(ForumSearchSpecial.trade.value);

  List<ForumSearchOrderOption> get orderOptions => hasTradeSpecial
      ? forumSearchTradeOrderOptions
      : forumSearchDefaultOrderOptions;

  String get effectiveOrderby {
    final values = orderOptions.map((e) => e.value).toSet();
    if (values.contains(orderby)) return orderby;
    return orderOptions.first.value;
  }

  bool get isDefault =>
      trimmedAuthor.isEmpty &&
      filter == ForumSearchFilter.all &&
      specials.isEmpty &&
      srchfromSeconds == 0 &&
      !before &&
      effectiveOrderby == 'lastpost' &&
      !ascending &&
      forumIds.isEmpty;

  int get activeFilterCount {
    var count = 0;
    if (trimmedAuthor.isNotEmpty) count++;
    if (filter != ForumSearchFilter.all) count++;
    if (specials.isNotEmpty) count++;
    if (srchfromSeconds > 0) count++;
    if (before) count++;
    if (effectiveOrderby != 'lastpost' || ascending) count++;
    if (forumIds.isNotEmpty) count++;
    return count;
  }

  /// 关键词与作者至少填一项。
  String? validate() {
    if (trimmedKeyword.isEmpty && trimmedAuthor.isEmpty) {
      return '请输入关键词或作者';
    }
    if (trimmedKeyword.length > maxTextLength ||
        trimmedAuthor.length > maxTextLength) {
      return '关键词与作者最多 $maxTextLength 个字符';
    }
    return null;
  }

  ForumSearchQuery copyWith({
    String? keyword,
    String? author,
    ForumSearchFilter? filter,
    Set<int>? specials,
    int? srchfromSeconds,
    bool? before,
    String? orderby,
    bool? ascending,
    Set<String>? forumIds,
  }) {
    return ForumSearchQuery(
      keyword: keyword ?? this.keyword,
      author: author ?? this.author,
      filter: filter ?? this.filter,
      specials: specials ?? this.specials,
      srchfromSeconds: srchfromSeconds ?? this.srchfromSeconds,
      before: before ?? this.before,
      orderby: orderby ?? this.orderby,
      ascending: ascending ?? this.ascending,
      forumIds: forumIds ?? this.forumIds,
    );
  }

  /// 生成 Discuz 搜索 POST 字段（不含 `formhash`）。
  Map<String, dynamic> toPostFields() {
    final fields = <String, dynamic>{
      'srchtxt': trimmedKeyword,
      'searchsubmit': 'yes',
    };

    if (trimmedAuthor.isNotEmpty) {
      fields['srchuname'] = trimmedAuthor;
    }
    if (filter != ForumSearchFilter.all) {
      fields['srchfilter'] = filter.value;
    }
    if (specials.isNotEmpty) {
      // Dio multiCompatible 会在 key 后追加 []；勿手写 special[] 以免变成 special[][]。
      fields['special'] = specials.map((e) => e.toString()).toList()..sort();
    }
    if (srchfromSeconds > 0) {
      fields['srchfrom'] = srchfromSeconds.toString();
    }
    if (before) {
      fields['before'] = '1';
    }
    if (effectiveOrderby != 'lastpost' || ascending) {
      fields['orderby'] = effectiveOrderby;
      fields['ascdesc'] = ascending ? 'asc' : 'desc';
    }
    if (forumIds.isNotEmpty) {
      fields['srchfid'] = forumIds.toList()..sort();
    } else if (!isDefault) {
      // 高级搜索默认「全部版块」须显式传 all，与网页 <select> 默认选中一致。
      fields['srchfid'] = ['all'];
    }

    return fields;
  }

  /// 用于结果区展示的简短摘要。
  List<String> summaryParts() {
    final parts = <String>[];
    if (trimmedAuthor.isNotEmpty) {
      parts.add('作者: $trimmedAuthor');
    }
    if (filter != ForumSearchFilter.all) {
      parts.add(filter.label);
    }
    for (final special in ForumSearchSpecial.values) {
      if (specials.contains(special.value)) {
        parts.add(special.label);
      }
    }
    if (srchfromSeconds > 0) {
      final timeLabel = forumSearchTimeOptions
          .firstWhere(
            (e) => e.seconds == srchfromSeconds,
            orElse: () => const ForumSearchTimeOption(
              seconds: 0,
              label: '限定时间',
            ),
          )
          .label;
      parts.add('$timeLabel${before ? '以前' : '以内'}');
    }
    if (effectiveOrderby != 'lastpost' || ascending) {
      final orderLabel = orderOptions
          .firstWhere(
            (e) => e.value == effectiveOrderby,
            orElse: () => ForumSearchOrderOption(
              value: effectiveOrderby,
              label: effectiveOrderby,
            ),
          )
          .label;
      parts.add('$orderLabel${ascending ? '升序' : '降序'}');
    }
    if (forumIds.isNotEmpty) {
      parts.add('${forumIds.length} 个版块');
    }
    return parts;
  }
}
