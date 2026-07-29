import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/forum_category.dart';
import '../models/forum_search_query.dart';
import '../providers/forum_list_provider.dart';
import '../theme/app_theme.dart';
import '../theme/s1_haptics.dart';
import 's1_adaptive_sheet.dart';

const _sheetMaxHeightFactor = 0.85;

const _filterSegmentLabels = <ForumSearchFilter, String>{
  ForumSearchFilter.all: '全部',
  ForumSearchFilter.digest: '精华',
  ForumSearchFilter.top: '置顶',
};

const _specialChipLabels = <ForumSearchSpecial, String>{
  ForumSearchSpecial.poll: '投票',
  ForumSearchSpecial.trade: '商品',
  ForumSearchSpecial.reward: '悬赏',
  ForumSearchSpecial.activity: '活动',
  ForumSearchSpecial.debate: '辩论',
};

Future<ForumSearchQuery?> showForumSearchAdvancedSheet({
  required BuildContext context,
  required ForumSearchQuery initialQuery,
}) {
  return showS1AdaptiveSheet<ForumSearchQuery>(
    context: context,
    isScrollControlled: true,
    desktopMaxWidth: 640,
    builder: (ctx) => ForumSearchAdvancedSheet(initialQuery: initialQuery),
  );
}

class ForumSearchAdvancedSheet extends ConsumerStatefulWidget {
  const ForumSearchAdvancedSheet({
    super.key,
    required this.initialQuery,
  });

  final ForumSearchQuery initialQuery;

  @override
  ConsumerState<ForumSearchAdvancedSheet> createState() =>
      _ForumSearchAdvancedSheetState();
}

class _ForumSearchAdvancedSheetState
    extends ConsumerState<ForumSearchAdvancedSheet> {
  late final TextEditingController _keywordController;
  late final TextEditingController _authorController;
  late ForumSearchFilter _filter;
  late Set<int> _specials;
  late int _srchfromSeconds;
  late bool _before;
  late String _orderby;
  late bool _ascending;
  late Set<String> _forumIds;
  String? _error;

  @override
  void initState() {
    super.initState();
    final q = widget.initialQuery;
    _keywordController = TextEditingController(text: q.keyword);
    _authorController = TextEditingController(text: q.author);
    _filter = q.filter;
    _specials = Set<int>.from(q.specials);
    _srchfromSeconds = q.srchfromSeconds;
    _before = q.before;
    _orderby = q.effectiveOrderby;
    _ascending = q.ascending;
    _forumIds = Set<String>.from(q.forumIds);
  }

  @override
  void dispose() {
    _keywordController.dispose();
    _authorController.dispose();
    super.dispose();
  }

  ForumSearchQuery _buildQuery() {
    return ForumSearchQuery(
      keyword: _keywordController.text,
      author: _authorController.text,
      filter: _filter,
      specials: _specials,
      srchfromSeconds: _srchfromSeconds,
      before: _before,
      orderby: _orderby,
      ascending: _ascending,
      forumIds: _forumIds,
    );
  }

  bool get _hasTradeSpecial =>
      _specials.contains(ForumSearchSpecial.trade.value);

  List<ForumSearchOrderOption> get _orderOptions {
    return _hasTradeSpecial
        ? forumSearchTradeOrderOptions
        : forumSearchDefaultOrderOptions;
  }

  String get _effectiveOrderby {
    final values = _orderOptions.map((e) => e.value).toSet();
    if (values.contains(_orderby)) return _orderby;
    return _orderOptions.first.value;
  }

  void _toggleSpecial(int value) {
    setState(() {
      if (_specials.contains(value)) {
        _specials.remove(value);
      } else {
        _specials.add(value);
      }
      if (!_orderOptions.any((e) => e.value == _orderby)) {
        _orderby = _orderOptions.first.value;
      }
    });
  }

  Future<void> _pickForums() async {
    final forumsAsync = ref.read(forumListProvider);
    if (forumsAsync.isLoading) {
      setState(() => _error = '版块列表加载中，请稍后再试');
      return;
    }
    if (forumsAsync.hasError) {
      setState(() => _error = '版块列表加载失败，请稍后重试');
      return;
    }
    final categories = forumsAsync.requireValue;
    final picked = await showS1AdaptiveSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      desktopMaxWidth: 480,
      builder: (ctx) => _ForumScopePickerSheet(
        categories: categories,
        initialSelection: _forumIds,
      ),
    );
    if (picked != null) {
      setState(() => _forumIds = picked);
    }
  }

  void _submit() {
    final query = _buildQuery();
    final validationError = query.validate();
    if (validationError != null) {
      setState(() => _error = validationError);
      return;
    }
    S1Haptics.selection();
    Navigator.pop(context, query);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final maxSheetHeight =
        MediaQuery.sizeOf(context).height * _sheetMaxHeightFactor;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + bottomInset),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxSheetHeight),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('帖子高级搜索', style: textTheme.titleLarge),
            const SizedBox(height: 16),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _SectionLabel(text: '关键词', textTheme: textTheme),
                    const SizedBox(height: 8),
                    Theme(
                      data: Theme.of(context).copyWith(
                        inputDecorationTheme:
                            _searchAdvancedInputTheme(scheme),
                      ),
                      child: TextField(
                        controller: _keywordController,
                        maxLength: ForumSearchQuery.maxTextLength,
                        decoration: const InputDecoration(
                          hintText: '请输入搜索内容',
                          counterText: '',
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _SectionLabel(text: '作者', textTheme: textTheme),
                    const SizedBox(height: 8),
                    Theme(
                      data: Theme.of(context).copyWith(
                        inputDecorationTheme:
                            _searchAdvancedInputTheme(scheme),
                      ),
                      child: TextField(
                        controller: _authorController,
                        maxLength: ForumSearchQuery.maxTextLength,
                        decoration: const InputDecoration(
                          hintText: '按用户名筛选',
                          counterText: '',
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _SectionLabel(text: '主题范围', textTheme: textTheme),
                    const SizedBox(height: 8),
                    SegmentedButton<ForumSearchFilter>(
                      segments: ForumSearchFilter.values
                          .map(
                            (f) => ButtonSegment(
                              value: f,
                              label: Text(_filterSegmentLabels[f]!),
                            ),
                          )
                          .toList(),
                      selected: {_filter},
                      showSelectedIcon: false,
                      onSelectionChanged: (value) {
                        setState(() => _filter = value.first);
                      },
                      style: S1SegmentedButtonStyle.forScheme(scheme),
                    ),
                    const SizedBox(height: 16),
                    _SectionLabel(text: '特殊主题', textTheme: textTheme),
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (final special in ForumSearchSpecial.values)
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: FilterChip(
                                label: Text(_specialChipLabels[special]!),
                                selected: _specials.contains(special.value),
                                showCheckmark: false,
                                side: BorderSide.none,
                                onSelected: (_) =>
                                    _toggleSpecial(special.value),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _SectionLabel(text: '搜索时间', textTheme: textTheme),
                    const SizedBox(height: 8),
                    _SearchAdvancedDropdownMenu<int>(
                      initialSelection: _srchfromSeconds,
                      entries: [
                        for (final option in forumSearchTimeOptions)
                          (value: option.seconds, label: option.label),
                      ],
                      onSelected: (value) {
                        if (value == null) return;
                        setState(() => _srchfromSeconds = value);
                      },
                    ),
                    const SizedBox(height: 8),
                    SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment(value: false, label: Text('以内')),
                        ButtonSegment(value: true, label: Text('以前')),
                      ],
                      selected: {_before},
                      showSelectedIcon: false,
                      onSelectionChanged: (value) {
                        setState(() => _before = value.first);
                      },
                      style: S1SegmentedButtonStyle.forScheme(scheme),
                    ),
                    const SizedBox(height: 16),
                    _SectionLabel(text: '排序类型', textTheme: textTheme),
                    const SizedBox(height: 8),
                    _SearchAdvancedDropdownMenu<String>(
                      key: ValueKey('orderby-trade-$_hasTradeSpecial'),
                      initialSelection: _effectiveOrderby,
                      entries: [
                        for (final option in _orderOptions)
                          (value: option.value, label: option.label),
                      ],
                      onSelected: (value) {
                        if (value == null) return;
                        setState(() => _orderby = value);
                      },
                    ),
                    const SizedBox(height: 8),
                    SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment(value: true, label: Text('升序')),
                        ButtonSegment(value: false, label: Text('降序')),
                      ],
                      selected: {_ascending},
                      showSelectedIcon: false,
                      onSelectionChanged: (value) {
                        setState(() => _ascending = value.first);
                      },
                      style: S1SegmentedButtonStyle.forScheme(scheme),
                    ),
                    const SizedBox(height: 16),
                    _SectionLabel(text: '搜索范围', textTheme: textTheme),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: _pickForums,
                      icon: const Icon(Icons.forum_outlined),
                      label: Text(
                        _forumIds.isEmpty
                            ? '全部版块'
                            : '已选 ${_forumIds.length} 个版块',
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _error!,
                        style: textTheme.bodyMedium?.copyWith(
                          color: scheme.error,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _submit,
              child: const Text('搜索'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({
    required this.text,
    required this.textTheme,
  });

  final String text;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: textTheme.titleSmall);
  }
}

InputDecorationTheme _searchAdvancedInputTheme(ColorScheme scheme) {
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

class _SearchAdvancedDropdownMenu<T> extends StatelessWidget {
  const _SearchAdvancedDropdownMenu({
    super.key,
    required this.initialSelection,
    required this.entries,
    required this.onSelected,
  });

  final T initialSelection;
  final List<({T value, String label})> entries;
  final ValueChanged<T?> onSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return DropdownMenu<T>(
      initialSelection: initialSelection,
      expandedInsets: EdgeInsets.zero,
      inputDecorationTheme: _searchAdvancedInputTheme(scheme),
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
          DropdownMenuEntry<T>(
            value: entry.value,
            label: entry.label,
            style: ButtonStyle(
              textStyle: WidgetStatePropertyAll(textTheme.bodyLarge),
              maximumSize: const WidgetStatePropertyAll(
                Size(double.infinity, double.infinity),
              ),
            ),
          ),
      ],
      onSelected: onSelected,
    );
  }
}

class _ForumScopePickerSheet extends StatefulWidget {
  const _ForumScopePickerSheet({
    required this.categories,
    required this.initialSelection,
  });

  final List<ForumCategory> categories;
  final Set<String> initialSelection;

  @override
  State<_ForumScopePickerSheet> createState() => _ForumScopePickerSheetState();
}

class _ForumScopePickerSheetState extends State<_ForumScopePickerSheet> {
  late Set<String> _selected;
  late bool _allForums;

  @override
  void initState() {
    super.initState();
    _selected = Set<String>.from(widget.initialSelection);
    _allForums = _selected.isEmpty;
  }

  void _toggleAll(bool? value) {
    setState(() {
      _allForums = value ?? false;
      if (_allForums) {
        _selected.clear();
      }
    });
  }

  void _toggleForum(String fid, bool? value) {
    setState(() {
      _allForums = false;
      if (value ?? false) {
        _selected.add(fid);
      } else {
        _selected.remove(fid);
      }
      if (_selected.isEmpty) {
        _allForums = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final maxSheetHeight =
        MediaQuery.sizeOf(context).height * _sheetMaxHeightFactor;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + bottomInset),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxSheetHeight),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('选择版块', style: textTheme.titleLarge),
            const SizedBox(height: 8),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('全部版块'),
              value: _allForums,
              onChanged: _toggleAll,
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final category in widget.categories) ...[
                    if (category.subforums.isEmpty)
                      CheckboxListTile(
                        contentPadding: const EdgeInsets.only(left: 8),
                        title: Text(category.name),
                        value: !_allForums && _selected.contains(category.fid),
                        onChanged: (value) => _toggleForum(category.fid, value),
                      )
                    else ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(8, 12, 8, 4),
                        child: Text(
                          category.name,
                          style: textTheme.labelLarge,
                        ),
                      ),
                      for (final sub in category.subforums)
                        CheckboxListTile(
                          contentPadding: const EdgeInsets.only(left: 24),
                          title: Text(sub.name),
                          value: !_allForums && _selected.contains(sub.fid),
                          onChanged: (value) => _toggleForum(sub.fid, value),
                        ),
                    ],
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () {
                S1Haptics.selection();
                Navigator.pop(context, _allForums ? <String>{} : _selected);
              },
              child: const Text('确定'),
            ),
          ],
        ),
      ),
    );
  }
}
