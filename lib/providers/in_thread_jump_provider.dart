import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 同帖引用跳转前的阅读位置快照。
class InThreadJumpSnapshot {
  const InThreadJumpSnapshot({
    required this.page,
    required this.absoluteFloor,
  });

  final int page;
  final int absoluteFloor;
}

/// 同帖 `replace(?pid=)` 的返回栈（按 tid）；存 Provider 以免详情 State remount 丢栈。
class InThreadJumpStack extends Notifier<List<InThreadJumpSnapshot>> {
  InThreadJumpStack(this.tid);

  final String tid;

  @override
  List<InThreadJumpSnapshot> build() => const [];

  void push(InThreadJumpSnapshot snapshot) {
    state = [...state, snapshot];
  }

  InThreadJumpSnapshot? pop() {
    if (state.isEmpty) return null;
    final next = [...state];
    final snapshot = next.removeLast();
    state = next;
    return snapshot;
  }

  void clear() => state = const [];
}

final inThreadJumpStackProvider = NotifierProvider.family<InThreadJumpStack,
    List<InThreadJumpSnapshot>, String>(
  InThreadJumpStack.new,
);
