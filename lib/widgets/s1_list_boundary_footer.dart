import 'package:flutter/material.dart';

/// 列表/分页页底常驻尾注种类。
enum S1ListBoundaryKind {
  /// 非末页：提示可继续翻页。
  pageContinue,

  /// 分页末页。
  lastPage,

  /// 单页或无分页场景的列表末端。
  listEnd,

  /// 无限滚动无更多。
  noMore,
}

/// M3 页底尾注：弱对比 label，不抢内容。
class S1ListBoundaryFooter extends StatelessWidget {
  const S1ListBoundaryFooter({
    super.key,
    required this.kind,
    this.padding = const EdgeInsets.fromLTRB(16, 20, 16, 12),
  });

  final S1ListBoundaryKind kind;
  final EdgeInsetsGeometry padding;

  static String labelFor(S1ListBoundaryKind kind) {
    return switch (kind) {
      S1ListBoundaryKind.pageContinue => '本页到底 · 左滑或点下一页',
      S1ListBoundaryKind.lastPage => '已是末页',
      S1ListBoundaryKind.listEnd => '已经到底',
      S1ListBoundaryKind.noMore => '没有更多了',
    };
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final label = labelFor(kind);

    return Semantics(
      label: label,
      child: Padding(
        padding: padding,
        child: Center(
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: textTheme.labelMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

/// 根据当前页与总页数选择分页尾注；单页用 [S1ListBoundaryKind.listEnd]。
S1ListBoundaryKind pagedBoundaryKind({
  required int currentPage,
  required int totalPages,
}) {
  if (totalPages <= 1) return S1ListBoundaryKind.listEnd;
  if (currentPage >= totalPages) return S1ListBoundaryKind.lastPage;
  return S1ListBoundaryKind.pageContinue;
}
