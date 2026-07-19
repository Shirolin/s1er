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

    test('FAB keeps M3 default elevation (not forced to 0)', () {
      final theme = AppTheme.lightTheme('purple');
      // Not overridden — FloatingActionButton falls back to M3 defaults (~6).
      expect(theme.floatingActionButtonTheme.elevation, isNull);
      expect(theme.floatingActionButtonTheme.highlightElevation, isNull);
    });

    test('S1Shape matches Flutter M3 radius scale', () {
      expect(S1Shape.extraSmall, const BorderRadius.all(Radius.circular(4)));
      expect(S1Shape.small, const BorderRadius.all(Radius.circular(8)));
      expect(S1Shape.medium, const BorderRadius.all(Radius.circular(12)));
      expect(S1Shape.large, const BorderRadius.all(Radius.circular(16)));
      expect(S1Shape.extraLarge, const BorderRadius.all(Radius.circular(28)));
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
      // 卡内嵌套：浅色 High/Highest，深于 Low 帖卡。
      expect(
        S1Surface.nestedPanel(lightScheme),
        lightScheme.surfaceContainerHigh,
      );
      expect(
        S1Surface.nestedPanelItem(lightScheme),
        lightScheme.surfaceContainerHighest,
      );
      expect(
        S1Surface.nestedPanel(lightScheme),
        isNot(S1Surface.card(lightScheme)),
      );
      // 弱浮层：与帖卡、画布均错开。
      expect(
        S1Surface.floatingControl(lightScheme),
        lightScheme.surfaceContainerHigh,
      );
      expect(
        S1Surface.floatingControl(lightScheme),
        isNot(S1Surface.card(lightScheme)),
      );
      expect(
        S1Surface.floatingControl(lightScheme),
        isNot(S1Surface.page(lightScheme)),
      );

      final dark = AppTheme.darkTheme('sand');
      final darkScheme = dark.colorScheme;
      expect(dark.scaffoldBackgroundColor, darkScheme.surfaceContainerLowest);
      expect(dark.cardTheme.color, darkScheme.surfaceContainerHigh);
      expect(
        S1BottomBarStyle.background(darkScheme),
        darkScheme.surfaceContainerLowest,
      );
      // 深色嵌套：Low 面板亮于 High 帖卡；条目 Highest 再沉一档。
      expect(
        S1Surface.nestedPanel(darkScheme),
        darkScheme.surfaceContainerLow,
      );
      expect(
        S1Surface.nestedPanelItem(darkScheme),
        darkScheme.surfaceContainerHighest,
      );
      expect(
        S1Surface.nestedPanel(darkScheme),
        isNot(S1Surface.card(darkScheme)),
      );
      expect(
        S1Surface.floatingControl(darkScheme),
        darkScheme.surfaceContainerHighest,
      );
      expect(
        S1Surface.floatingControl(darkScheme),
        isNot(S1Surface.card(darkScheme)),
      );
      expect(
        S1Surface.floatingControl(darkScheme),
        isNot(S1Surface.page(darkScheme)),
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
