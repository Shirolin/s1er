import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s1_app/theme/app_theme.dart';

void main() {
  group('AppTheme M3 compliance', () {
    test('useMaterial3 is enabled', () {
      final theme = AppTheme.lightTheme('purple');
      expect(theme.useMaterial3, isTrue);
    });

    test('AppBar uses zero elevation', () {
      final theme = AppTheme.lightTheme('purple');
      expect(theme.appBarTheme.elevation, 0);
      expect(theme.appBarTheme.scrolledUnderElevation, 0);
    });

    test('Card and NavigationBar use zero elevation', () {
      final theme = AppTheme.lightTheme('purple');
      expect(theme.cardTheme.elevation, 0);
      expect(theme.navigationBarTheme.elevation, 0);
    });

    test('FAB uses zero elevation', () {
      final theme = AppTheme.lightTheme('purple');
      expect(theme.floatingActionButtonTheme.elevation, 0);
      expect(theme.floatingActionButtonTheme.highlightElevation, 0);
    });

    test('segmentedButtonTheme is configured', () {
      final theme = AppTheme.lightTheme('purple');
      expect(theme.segmentedButtonTheme.style, isNotNull);
    });

    test('tabBarTheme uses colorScheme tokens', () {
      final theme = AppTheme.lightTheme('purple');
      final scheme = theme.colorScheme;
      expect(theme.tabBarTheme.indicatorColor, scheme.primary);
      expect(theme.tabBarTheme.labelColor, scheme.primary);
      expect(theme.tabBarTheme.unselectedLabelColor, scheme.onSurfaceVariant);
    });

    test('themeSeeds contains all expected keys', () {
      expect(AppTheme.themeSeeds.keys, containsAll(['blue', 'purple', 'sage', 'indigo', 'orange']));
    });

    test('dark theme preserves M3 settings', () {
      final theme = AppTheme.darkTheme('blue');
      expect(theme.useMaterial3, isTrue);
      expect(theme.appBarTheme.elevation, 0);
      expect(theme.cardTheme.elevation, 0);
    });

    test('fromColorScheme works with dynamic color scheme', () {
      final scheme = ColorScheme.fromSeed(
        seedColor: Colors.teal,
        brightness: Brightness.light,
      );
      final theme = AppTheme.fromColorScheme(scheme);
      expect(theme.useMaterial3, isTrue);
      expect(theme.colorScheme.primary, scheme.primary);
    });

    test('progressIndicatorTheme is configured', () {
      final theme = AppTheme.lightTheme('purple');
      expect(theme.progressIndicatorTheme.color, theme.colorScheme.primary);
    });

    test('badgeTheme and checkboxTheme are configured', () {
      final theme = AppTheme.lightTheme('purple');
      expect(theme.badgeTheme.backgroundColor, theme.colorScheme.secondaryContainer);
      expect(theme.checkboxTheme.checkColor, isNotNull);
    });

    test('S1Typography defaults match settings', () {
      expect(S1Typography.defaultBodySize, 14);
      expect(S1Typography.defaultCodeSize, 12);
    });
  });
}
