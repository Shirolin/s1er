import 'package:flutter/material.dart';

import '../theme/s1_haptics.dart';
import 's1_snack_bar.dart';

/// 边界越界方向 / 场景标识（同种类节流）。
enum BoundaryEdge {
  /// 第 1 页再试图翻上一页（横滑）。
  firstPage,

  /// 末页再试图翻下一页（横滑）。
  lastPage,

  /// 末端列表再下拉（纵滑触底）。
  listEnd,
}

/// 混合边界反馈：同 [edge] 首次仅轻触觉，冷却窗内再次才 SnackBar。
///
/// 同一连续手势内的高频回调（overscroll）会被 [gestureDebounce] 吞掉，
/// 避免一次拖拽就立刻弹出文案。
class BoundaryFeedbackController {
  BoundaryFeedbackController({
    this.repeatWindow = const Duration(milliseconds: 1500),
    this.gestureDebounce = const Duration(milliseconds: 400),
    this.snackDuration = const Duration(milliseconds: 1800),
    DateTime Function()? clock,
    void Function()? onHaptic,
    void Function(BuildContext context, String message)? onShowMessage,
  })  : _clock = clock ?? DateTime.now,
        _onHaptic = onHaptic,
        _onShowMessage = onShowMessage;

  /// 同方向再次越界触发文案的时间窗（相对上次已受理的 hit）。
  final Duration repeatWindow;

  /// 同方向过近的重复 hit 视为同一手势，忽略。
  final Duration gestureDebounce;

  final Duration snackDuration;

  final DateTime Function() _clock;
  final void Function()? _onHaptic;
  final void Function(BuildContext context, String message)? _onShowMessage;

  BoundaryEdge? _lastEdge;
  DateTime? _lastAt;

  /// 处理一次越界。返回是否展示了文案（便于测试）。
  bool hit(
    BuildContext context,
    BoundaryEdge edge, {
    String? message,
  }) {
    final now = _clock();
    final text = message ?? defaultMessage(edge);
    final sinceLast = _lastAt == null ? null : now.difference(_lastAt!);

    if (_lastEdge == edge && sinceLast != null && sinceLast < gestureDebounce) {
      return false;
    }

    final isRepeat =
        _lastEdge == edge && sinceLast != null && sinceLast <= repeatWindow;

    _lastEdge = edge;
    _lastAt = now;

    if (isRepeat) {
      _show(context, text);
      return true;
    }

    if (_onHaptic != null) {
      _onHaptic();
    } else {
      S1Haptics.light();
    }
    return false;
  }

  void _show(BuildContext context, String message) {
    if (_onShowMessage != null) {
      _onShowMessage(context, message);
      return;
    }
    if (!context.mounted) return;
    S1SnackBar.show(
      context,
      message: message,
      duration: snackDuration,
    );
  }

  /// 重置节流状态（翻页成功后可调用）。
  void reset() {
    _lastEdge = null;
    _lastAt = null;
  }

  static String defaultMessage(BoundaryEdge edge) {
    return switch (edge) {
      BoundaryEdge.firstPage => '已是首页',
      BoundaryEdge.lastPage => '已是末页',
      BoundaryEdge.listEnd => '已经到底',
    };
  }
}
