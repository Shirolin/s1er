import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// 列表滚动动效：按距离自适应时长，校正阶段用短动画避免布局冲突。
abstract class S1ScrollMotion {
  static const Duration minDuration = Duration(milliseconds: 220);
  static const Duration maxDuration = Duration(milliseconds: 500);
  static const Duration bottomMaxDuration = Duration(milliseconds: 560);
  static const Duration correctionDuration = Duration(milliseconds: 140);

  static const double settleTolerance = 0.5;
  static const double silentCorrectionFraction = 0.18;

  /// 视口比例 → 时长：短距轻快，长距封顶。
  static Duration durationForDelta(
    double delta,
    double viewport, {
    bool toBottom = false,
  }) {
    if (viewport <= 0) return minDuration;
    final normalized = (delta / viewport).clamp(0.0, 3.5);
    final ms = 200 + normalized * normalized * 240;
    final cap = toBottom ? bottomMaxDuration.inMilliseconds : maxDuration.inMilliseconds;
    return Duration(milliseconds: ms.round().clamp(minDuration.inMilliseconds, cap));
  }

  static Curve curveForDelta(double delta, double viewport) {
    if (viewport <= 0) return Curves.easeOutCubic;
    return delta < viewport * 0.55 ? Curves.easeOutCubic : Curves.easeInOutCubic;
  }

  /// 滚至固定目标；已到位则跳过。
  static Future<void> animateTo(
    ScrollPosition position,
    double target, {
    Duration? duration,
    Curve? curve,
    double tolerance = settleTolerance,
  }) async {
    if (!position.hasPixels) return;

    final clamped = target.clamp(position.minScrollExtent, position.maxScrollExtent);
    final delta = (clamped - position.pixels).abs();
    if (delta <= tolerance) return;

    final viewport = position.viewportDimension;
    await position.animateTo(
      clamped,
      duration: duration ?? durationForDelta(delta, viewport),
      curve: curve ?? curveForDelta(delta, viewport),
    );
  }

  /// 滚向动态终点（懒加载列表 [maxScrollExtent] 会增长）。
  static Future<void> animateToMaxExtent(
    ScrollPosition position, {
    int maxPasses = 5,
  }) async {
    for (var pass = 0; pass < maxPasses; pass++) {
      if (!position.hasPixels) return;

      final max = position.maxScrollExtent;
      final delta = max - position.pixels;
      if (delta <= settleTolerance) return;

      await animateTo(
        position,
        max,
        duration: pass == 0
            ? durationForDelta(delta, position.viewportDimension, toBottom: true)
            : correctionDuration,
        curve: pass == 0 ? null : Curves.easeOut,
      );
      await _waitForLayout();
      if (!position.hasPixels) return;

      final remaining = position.maxScrollExtent - position.pixels;
      if (remaining <= settleTolerance) return;
      if (remaining <= position.viewportDimension * silentCorrectionFraction) {
        await animateTo(
          position,
          position.maxScrollExtent,
          duration: correctionDuration,
          curve: Curves.easeOut,
        );
        return;
      }
    }

    if (!position.hasPixels) return;
    if (position.pixels < position.maxScrollExtent - settleTolerance) {
      await animateTo(
        position,
        position.maxScrollExtent,
        duration: correctionDuration,
        curve: Curves.easeOut,
      );
    }
  }

  /// 小幅校正：短动画对齐，避免同步 [jumpTo] 引发布局断言。
  static Future<void> correctSilentlyIfNeeded(
    ScrollPosition position,
    double target,
  ) async {
    if (!position.hasPixels) return;

    final clamped = target.clamp(position.minScrollExtent, position.maxScrollExtent);
    final delta = (clamped - position.pixels).abs();
    if (delta <= settleTolerance) return;

    final threshold = position.viewportDimension * silentCorrectionFraction;
    if (delta <= threshold) {
      await animateTo(
        position,
        clamped,
        duration: correctionDuration,
        curve: Curves.easeOut,
      );
    }
  }

  static Future<void> _waitForLayout() {
    final completer = Completer<void>();
    SchedulerBinding.instance.scheduleFrameCallback((_) {
      completer.complete();
    });
    return completer.future;
  }
}
