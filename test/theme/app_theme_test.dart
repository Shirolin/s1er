import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s1er/theme/app_theme.dart';

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
      final style = theme.segmentedButtonTheme.style;
      expect(style, isNotNull);
      expect(style!.tapTargetSize, MaterialTapTargetSize.padded);
      expect(
        style.shape?.resolve(<WidgetState>{}),
        isA<RoundedRectangleBorder>().having(
          (shape) => shape.borderRadius,
          'borderRadius',
          S1Shape.full,
        ),
      );
    });

    test('tabBarTheme uses colorScheme tokens', () {
      final theme = AppTheme.lightTheme('purple');
      final scheme = theme.colorScheme;
      expect(theme.tabBarTheme.indicatorColor, scheme.primary);
      expect(theme.tabBarTheme.labelColor, scheme.primary);
      expect(theme.tabBarTheme.unselectedLabelColor, scheme.onSurfaceVariant);
    });

    test('themeSeeds contains all expected keys', () {
      expect(
        AppTheme.themeSeeds.keys,
        containsAll(['blue', 'sand', 'purple', 'sage', 'rose']),
      );
      expect(AppTheme.themeSeeds['blue'], const Color(0xFF00639B));
      expect(AppTheme.themeSeeds['sand'], const Color(0xFF825500));
    });

    test('surface hierarchy matches Reply canvas / content / chrome', () {
      final light = AppTheme.lightTheme('sand');
      final lightScheme = light.colorScheme;
      // 画布更深；内容奶油沙色；铬件与画布齐平。
      expect(
        light.scaffoldBackgroundColor,
        lightScheme.surfaceContainerHighest,
      );
      expect(light.cardTheme.color, lightScheme.surfaceContainerLow);
      expect(
        light.appBarTheme.backgroundColor,
        lightScheme.surfaceContainerHighest,
      );
      expect(
        light.searchBarTheme.backgroundColor?.resolve(const {}),
        lightScheme.surfaceContainerLow,
      );
      expect(
        S1BottomBarStyle.background(lightScheme),
        lightScheme.surfaceContainerHighest,
      );
      expect(
        light.navigationRailTheme.backgroundColor,
        lightScheme.surfaceContainerHighest,
      );
      expect(
        light.floatingActionButtonTheme.backgroundColor,
        lightScheme.tertiaryContainer,
      );

      final dark = AppTheme.darkTheme('sand');
      final darkScheme = dark.colorScheme;
      expect(dark.scaffoldBackgroundColor, darkScheme.surfaceContainerLowest);
      expect(dark.cardTheme.color, darkScheme.surfaceContainerHigh);
      expect(
        S1BottomBarStyle.background(darkScheme),
        darkScheme.surfaceContainerLowest,
      );
    });

    test('cards and chips are borderless tonal surfaces', () {
      final theme = AppTheme.lightTheme('sand');
      final cardShape = theme.cardTheme.shape;
      expect(cardShape, isA<RoundedRectangleBorder>());
      expect(
        (cardShape! as RoundedRectangleBorder).side,
        BorderSide.none,
      );
      expect(theme.cardTheme.surfaceTintColor, Colors.transparent);
      expect(theme.chipTheme.side, BorderSide.none);
      expect(
        (theme.chipTheme.shape! as RoundedRectangleBorder).side,
        BorderSide.none,
      );
    });

    test('custom and unknown theme colors fall back to the default preset', () {
      expect(AppTheme.normalizeThemeColorKey('#2B2930'), 'sand');
      expect(AppTheme.normalizeThemeColorKey('unknown'), 'sand');
      expect(AppTheme.normalizeThemeColorKey('sage'), 'sage');
      expect(AppTheme.normalizeThemeColorKey('indigo'), 'rose');
      expect(AppTheme.normalizeThemeColorKey('orange'), 'sand');
      expect(AppTheme.normalizeThemeColorKey('sand'), 'sand');
      expect(
        AppTheme.lightTheme('#2B2930').colorScheme,
        AppTheme.lightTheme('sand').colorScheme,
      );
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
      expect(
        theme.badgeTheme.backgroundColor,
        theme.colorScheme.secondaryContainer,
      );
      expect(theme.checkboxTheme.checkColor, isNotNull);
    });

    test('S1Typography defaults match settings', () {
      expect(S1Typography.defaultBodySize, 14);
      expect(S1Typography.defaultCodeSize, 12);
    });
  });
}
