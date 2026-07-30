import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s1er/widgets/s1_swipe_pagination.dart';

/// 三槽 PageView 中心槽（index 1）的滚动 metrics 替身。
class _CenterSlotMetrics extends FixedScrollMetrics {
  _CenterSlotMetrics({
    required double viewportDimension,
  }) : super(
          minScrollExtent: 0,
          maxScrollExtent: viewportDimension * 2,
          pixels: viewportDimension,
          viewportDimension: viewportDimension,
          devicePixelRatio: 1,
          axisDirection: AxisDirection.right,
        );
}

void main() {
  test('BoundedSwipePaginationPhysics reads live page after external jump', () {
    var currentPage = 1;
    const totalPages = 5;
    const viewport = 400.0;

    final physics = BoundedSwipePaginationPhysics(
      getCurrentPage: () => currentPage,
      getTotalPages: () => totalPages,
    );
    final metrics = _CenterSlotMetrics(viewportDimension: viewport);

    // 第 1 页：往「上一页」方向拖（pixels 减小）应被挡住。
    final blockedOnFirstPage = physics.applyBoundaryConditions(
      metrics,
      metrics.pixels - 10,
    );
    expect(blockedOnFirstPage, lessThan(0));

    expect(
      physics.createBallisticSimulation(metrics, -500),
      isNull,
    );

    // 外部分页到末页：同一 physics 实例，仅页码变。
    currentPage = totalPages;

    final allowedOnLastPage = physics.applyBoundaryConditions(
      metrics,
      metrics.pixels - 10,
    );
    expect(allowedOnLastPage, 0);

    expect(
      physics.createBallisticSimulation(metrics, -500),
      isNotNull,
    );
  });

  test('BoundedSwipePaginationPhysics applyTo preserves page getters', () {
    var currentPage = 3;
    final physics = BoundedSwipePaginationPhysics(
      getCurrentPage: () => currentPage,
      getTotalPages: () => 5,
    );
    final applied = physics.applyTo(const ClampingScrollPhysics());
    expect(applied, isA<BoundedSwipePaginationPhysics>());

    currentPage = 5;
    final metrics = _CenterSlotMetrics(viewportDimension: 300);
    expect(
      applied.createBallisticSimulation(metrics, -500),
      isNotNull,
    );
  });
}
