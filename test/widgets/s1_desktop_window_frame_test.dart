import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s1er/utils/desktop_window.dart';
import 'package:s1er/widgets/s1_desktop_window_frame.dart';
import 'package:s1er/widgets/s1_window_title_bar.dart';
import 'package:window_manager/window_manager.dart';

import '../helpers/test_theme.dart';

class _FakeDesktopWindowController extends DesktopWindowController {
  bool maximized = false;
  int minimizeCount = 0;
  int closeCount = 0;
  int toggleCount = 0;
  final listeners = <WindowListener>[];

  @override
  Future<void> minimize() async {
    minimizeCount++;
  }

  @override
  Future<void> toggleMaximize() async {
    toggleCount++;
    maximized = !maximized;
    for (final listener in List<WindowListener>.from(listeners)) {
      if (maximized) {
        listener.onWindowMaximize();
      } else {
        listener.onWindowUnmaximize();
      }
    }
  }

  @override
  Future<void> close() async {
    closeCount++;
  }

  @override
  Future<bool> isMaximized() async => maximized;

  @override
  void addListener(WindowListener listener) => listeners.add(listener);

  @override
  void removeListener(WindowListener listener) => listeners.remove(listener);
}

void main() {
  tearDown(() {
    S1DesktopWindow.supportedOverride = null;
    DesktopWindowController.testInstance = null;
    debugDefaultTargetPlatformOverride = null;
  });

  group('S1DesktopWindow.isSupported', () {
    test('false on Android by default', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      expect(S1DesktopWindow.isSupported, isFalse);
    });

    test('true on Windows', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      expect(S1DesktopWindow.isSupported, isTrue);
    });

    test('override wins over platform', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      S1DesktopWindow.supportedOverride = true;
      expect(S1DesktopWindow.isSupported, isTrue);
    });
  });

  group('S1DesktopWindowFrame', () {
    testWidgets('pass-through when unsupported', (tester) async {
      S1DesktopWindow.supportedOverride = false;
      await tester.pumpWidget(
        wrapWithAppTheme(
          const S1DesktopWindowFrame(
            child: Text('body'),
          ),
        ),
      );
      expect(find.text('body'), findsOneWidget);
      expect(find.byType(S1WindowTitleBar), findsNothing);
    });

    testWidgets('shows title bar and window buttons on desktop',
        (tester) async {
      S1DesktopWindow.supportedOverride = true;
      final fake = _FakeDesktopWindowController();
      DesktopWindowController.testInstance = fake;

      await tester.pumpWidget(
        wrapWithAppTheme(
          S1DesktopWindowFrame(
            controller: fake,
            child: const Text('body'),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(S1WindowTitleBar), findsOneWidget);
      expect(find.text('S1er'), findsOneWidget);
      expect(find.text('body'), findsOneWidget);
      expect(find.bySemanticsLabel('最小化'), findsOneWidget);
      expect(find.bySemanticsLabel('最大化'), findsOneWidget);
      expect(find.bySemanticsLabel('关闭'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('最小化'));
      await tester.pump();
      expect(fake.minimizeCount, 1);

      await tester.tap(find.bySemanticsLabel('最大化'));
      await tester.pump();
      expect(fake.toggleCount, 1);
      expect(find.bySemanticsLabel('还原'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('关闭'));
      await tester.pump();
      expect(fake.closeCount, 1);
    });
  });
}
