import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 本楼「去除特殊样式」的进程内会话集（按 `pid`）。
///
/// 仅存活于当前进程：杀进程 / 冷启动即清空，不持久化。与
/// [settingsProvider] 的全局开关取或得到楼层最终剥离状态。
class StripStylesSessionNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() => <String>{};

  bool isStripped(String pid) => state.contains(pid);

  void toggle(String pid) {
    if (pid.isEmpty) return;
    final next = Set<String>.from(state);
    if (!next.add(pid)) next.remove(pid);
    state = next;
  }

  void add(String pid) {
    if (pid.isEmpty || state.contains(pid)) return;
    state = {...state, pid};
  }

  void remove(String pid) {
    if (pid.isEmpty || !state.contains(pid)) return;
    final next = Set<String>.from(state)..remove(pid);
    state = next;
  }

  void clear() {
    if (state.isEmpty) return;
    state = <String>{};
  }
}

/// 当前会话中被本楼去除样式的 pid 集合。
final strippedStylePidsProvider =
    NotifierProvider<StripStylesSessionNotifier, Set<String>>(
  StripStylesSessionNotifier.new,
);
