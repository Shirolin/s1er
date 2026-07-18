/// Allowed capture pixel ratios for share-card export.
abstract final class SharePixelRatio {
  static const double balanced = 1.5;
  static const double standard = 2.0;
  static const double high = 3.0;

  static const double defaultValue = balanced;

  static const List<double> options = [balanced, standard, high];

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
}
