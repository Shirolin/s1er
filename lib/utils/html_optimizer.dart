import 'package:html/dom.dart';

/// HTML 节点层级合并优化器。
///
/// 针对部分使用富文本/模版生成器发帖产生的冗余标签（如连续的 `<font color="...">` 或 `<span>` 包裹微小字符/空格）
/// 进行无损的 DOM 结构扁平化处理，减少 `flutter_html` 引擎生成的 Widget 节点数量。
abstract class HtmlOptimizer {
  /// 全局优化总开关。
  ///
  /// 设为 `false` 时完全禁用 DOM 标签合并，恢复为 HTML 原始层级结构。
  static bool enableTagFlattening = true;

  /// 对 [fragment] 进行相邻相同属性标签的合并。
  static void flatten(DocumentFragment fragment) {
    if (!enableTagFlattening) return;
    _mergeSimilarSiblings(fragment);
  }

  /// 深度不可合并标签集合（自闭合、换行或独立元素，防止误吞换行符）
  static const _nonMergeableTags = {'br', 'hr', 'img'};

  /// 递归合并 node 下相邻且具有相同标签与属性的 Element 子节点。
  static void _mergeSimilarSiblings(Node node) {
    if (node.nodes.isEmpty) return;

    for (var i = 0; i < node.nodes.length - 1;) {
      final current = node.nodes[i];
      final next = node.nodes[i + 1];

      if (current is Element &&
          next is Element &&
          !_nonMergeableTags.contains(current.localName) &&
          current.localName == next.localName &&
          _areAttributesEqual(current.attributes, next.attributes)) {
        // 将 next 的所有子节点平移到 current 末尾
        while (next.nodes.isNotEmpty) {
          current.append(next.nodes.first);
        }
        next.remove();
        // 不递增 i，因为合并后的 current 可能还能与新的 next（原 i+2）继续合并
      } else {
        i++;
      }
    }

    // 递归对所有子节点进行深度合并
    for (final child in List<Node>.from(node.nodes)) {
      _mergeSimilarSiblings(child);
    }
  }

  static bool _areAttributesEqual(
    Map<dynamic, String> a,
    Map<dynamic, String> b,
  ) {
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (!b.containsKey(key) || a[key] != b[key]) {
        return false;
      }
    }
    return true;
  }
}
