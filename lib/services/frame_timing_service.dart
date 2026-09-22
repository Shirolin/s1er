import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

import 'talker.dart';

/// 帧耗时采集：按秒聚合 build / raster 超预算的掉帧，**仅在该秒存在掉帧
/// 时**写一条 Talker 警告，供 App 内 TalkerScreen（版本行点 5 下）查看。
///
/// 设计取舍：
/// - 不做全量逐帧日志（会刷爆 Talker 历史上限），只在掉帧秒聚合输出；
/// - 60Hz 下单帧预算 16.7ms，超过 2 帧预算（33.4ms）记 1 次严重掉帧；
/// - `kReleaseMode` 下同样生效，方便真机排查「卡卡的」类回帖。
class FrameTimingService {
  FrameTimingService._();

  static final FrameTimingService instance = FrameTimingService._();

  static const int _budgetMicros = 16667; // ~60fps 单帧预算
  static const int _severeBudgetMicros = 33334; // 连续两帧预算

  bool _registered = false;

  // 当前统计窗口（1 秒）的累计值。
  int _windowStartMs = 0;
  int _frames = 0;
  int _buildOverBudget = 0;
  int _rasterOverBudget = 0;
  int _severeFrames = 0;
  int _worstBuildMicros = 0;
  int _worstRasterMicros = 0;

  /// 注册 timings 回调；重复调用无副作用。
  void register() {
    if (_registered) return;
    _registered = true;
    SchedulerBinding.instance.addTimingsCallback(_onFrameTimings);
  }

  @visibleForTesting
  void reset() {
    _windowStartMs = 0;
    _frames = 0;
    _buildOverBudget = 0;
    _rasterOverBudget = 0;
    _severeFrames = 0;
    _worstBuildMicros = 0;
    _worstRasterMicros = 0;
  }

  void _onFrameTimings(List<FrameTiming> timings) {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    for (final timing in timings) {
      _accumulate(timing, nowMs);
    }
    _flushIfWindowElapsed();
  }

  void _accumulate(FrameTiming timing, int nowMs) {
    if (_windowStartMs == 0) {
      _windowStartMs = nowMs;
    } else if (nowMs - _windowStartMs >= 1000) {
      _flush(nowMs);
    }

    final build = timing.buildDuration.inMicroseconds;
    final raster = timing.rasterDuration.inMicroseconds;
    _frames++;
    if (build > _worstBuildMicros) _worstBuildMicros = build;
    if (raster > _worstRasterMicros) _worstRasterMicros = raster;
    if (build > _budgetMicros) _buildOverBudget++;
    if (raster > _budgetMicros) _rasterOverBudget++;
    if (build > _severeBudgetMicros || raster > _severeBudgetMicros) {
      _severeFrames++;
    }
  }

  void _flushIfWindowElapsed() {
    if (_windowStartMs == 0) return;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    if (nowMs - _windowStartMs >= 1000) {
      _flush(nowMs);
    }
  }

  void _flush(int nowMs) {
    final frames = _frames;
    final buildOver = _buildOverBudget;
    final rasterOver = _rasterOverBudget;
    final severe = _severeFrames;
    final worstBuild = _worstBuildMicros;
    final worstRaster = _worstRasterMicros;

    reset();
    _windowStartMs = nowMs;

    // 该秒无掉帧：静默，不刷历史。
    if (frames == 0 || (buildOver == 0 && rasterOver == 0)) return;

    String ms(int micros) => (micros / 1000).toStringAsFixed(1);
    talker.warning(
      '[frame-timing] $frames 帧窗口掉帧：'
      'build 超预算 $buildOver 帧（最差 ${ms(worstBuild)}ms）· '
      'raster 超预算 $rasterOver 帧（最差 ${ms(worstRaster)}ms）· '
      '严重掉帧 $severe 次',
    );
  }
}
