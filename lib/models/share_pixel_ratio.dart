/// Allowed capture pixel ratios for share-card export.
abstract final class SharePixelRatio {
  static const double compact = 1.25;
  static const double balanced = 1.5;
  static const double standard = 2.0;
  static const double high = 3.0;

  static const double defaultValue = balanced;

  static const List<double> options = [compact, balanced, standard, high];

  /// Share-card logical layout width. Keep in sync with [ShareCard.cardWidth].
  static const int logicalCardWidth = 600;

  static const List<SharePixelRatioOption> optionMeta = [
    SharePixelRatioOption(
      ratio: compact,
      name: '省流',
      hintSuffix: '文件更小',
    ),
    SharePixelRatioOption(
      ratio: balanced,
      name: '均衡',
      hintSuffix: '默认推荐',
    ),
    SharePixelRatioOption(
      ratio: standard,
      name: '标准',
      hintSuffix: '更清晰',
    ),
    SharePixelRatioOption(
      ratio: high,
      name: '高清',
      hintSuffix: '体积最大',
    ),
  ];

  /// Snap stored / backup values (int or double) onto [options].
  static double normalize(Object? raw) {
    final value = switch (raw) {
      num n => n.toDouble(),
      _ => defaultValue,
    };

    var best = options.first;
    var bestDist = (value - best).abs();
    for (final option in options.skip(1)) {
      final dist = (value - option).abs();
      if (dist < bestDist) {
        best = option;
        bestDist = dist;
      }
    }
    return best;
  }

  static SharePixelRatioOption optionFor(double ratio) {
    final normalized = normalize(ratio);
    return optionMeta.firstWhere((option) => option.ratio == normalized);
  }

  static int exportWidthPx(double ratio) {
    return (logicalCardWidth * normalize(ratio)).round();
  }

  static String multiplierLabel(double ratio) {
    final normalized = normalize(ratio);
    if (normalized == standard) return '2x';
    if (normalized == high) return '3x';
    if (normalized == compact) return '1.25x';
    return '1.5x';
  }

  static String subtitleFor(double ratio) {
    final option = optionFor(ratio);
    return '约 ${exportWidthPx(option.ratio)}px 宽，${option.hintSuffix}';
  }

  static String menuLabelFor(double ratio) {
    final option = optionFor(ratio);
    return '${option.name} ${multiplierLabel(option.ratio)}'
        '（约 ${exportWidthPx(option.ratio)}px）';
  }
}

/// User-facing metadata for a share export pixel ratio.
final class SharePixelRatioOption {
  const SharePixelRatioOption({
    required this.ratio,
    required this.name,
    required this.hintSuffix,
  });

  final double ratio;
  final String name;
  final String hintSuffix;
}
