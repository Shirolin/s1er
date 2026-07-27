import 'package:flutter/material.dart';

/// 异步列表首载：顶栏 indeterminate 进度 + 展开区骨架。
class S1AsyncListLoading extends StatelessWidget {
  const S1AsyncListLoading({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const LinearProgressIndicator(),
        Expanded(child: child),
      ],
    );
  }
}
