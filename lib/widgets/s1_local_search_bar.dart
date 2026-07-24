import 'package:flutter/material.dart';

/// AppBar 下方可展开的本页搜索条：即时 [onChanged]，无提交 / 冷却。
class S1LocalSearchBar extends StatefulWidget {
  const S1LocalSearchBar({
    super.key,
    required this.hintText,
    required this.query,
    required this.onChanged,
    this.onClose,
    this.matchCount,
    this.autofocus = true,
  });

  final String hintText;
  final String query;
  final ValueChanged<String> onChanged;

  /// 收起整条搜索（关闭本页搜索模式）。
  final VoidCallback? onClose;

  /// 非 null 时在 trailing 显示「N 条」。
  final int? matchCount;
  final bool autofocus;

  @override
  State<S1LocalSearchBar> createState() => _S1LocalSearchBarState();
}

class _S1LocalSearchBarState extends State<S1LocalSearchBar> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.query);
    _focusNode = FocusNode();
    if (widget.autofocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focusNode.requestFocus();
      });
    }
  }

  @override
  void didUpdateWidget(S1LocalSearchBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.query != _controller.text) {
      _controller.value = TextEditingValue(
        text: widget.query,
        selection: TextSelection.collapsed(offset: widget.query.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final hasQuery = widget.query.trim().isNotEmpty;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: SearchBar(
        controller: _controller,
        focusNode: _focusNode,
        hintText: widget.hintText,
        leading: const Icon(Icons.search),
        trailing: [
          if (widget.matchCount != null && hasQuery)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Text(
                '${widget.matchCount} 条',
                style: textTheme.labelMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          if (hasQuery)
            IconButton(
              tooltip: '清除',
              onPressed: () {
                _controller.clear();
                widget.onChanged('');
              },
              icon: const Icon(Icons.clear),
            ),
          if (widget.onClose != null)
            IconButton(
              tooltip: '关闭本页搜索',
              onPressed: widget.onClose,
              icon: const Icon(Icons.close),
            ),
        ],
        onChanged: widget.onChanged,
      ),
    );
  }
}
