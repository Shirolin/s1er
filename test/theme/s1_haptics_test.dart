import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s1er/theme/s1_haptics.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final calls = <MethodCall>[];

  setUp(() {
    S1Haptics.enabled = true;
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      calls.add(call);
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
    S1Haptics.enabled = true;
  });

  test('selection / light / medium / heavy map to platform args', () async {
    S1Haptics.selection();
    S1Haptics.light();
    S1Haptics.medium();
    S1Haptics.heavy();
    await Future<void>.delayed(Duration.zero);

    expect(
      calls.map((c) => '${c.method}:${c.arguments}').toList(),
      [
        'HapticFeedback.vibrate:HapticFeedbackType.selectionClick',
        'HapticFeedback.vibrate:HapticFeedbackType.lightImpact',
        'HapticFeedback.vibrate:HapticFeedbackType.mediumImpact',
        'HapticFeedback.vibrate:HapticFeedbackType.heavyImpact',
      ],
    );
  });

  test('disabled gate suppresses platform calls', () async {
    S1Haptics.enabled = false;
    S1Haptics.selection();
    S1Haptics.light();
    S1Haptics.medium();
    S1Haptics.heavy();
    await Future<void>.delayed(Duration.zero);
    expect(calls, isEmpty);
  });

  test('wrapTap fires selection before callback', () async {
    var ran = false;
    final wrapped = S1Haptics.wrapTap(() => ran = true);
    wrapped!();
    await Future<void>.delayed(Duration.zero);
    expect(ran, isTrue);
    expect(calls.single.arguments, 'HapticFeedbackType.selectionClick');
  });

  test('wrapLongPress fires medium before callback', () async {
    var ran = false;
    final wrapped = S1Haptics.wrapLongPress(() => ran = true);
    wrapped!();
    await Future<void>.delayed(Duration.zero);
    expect(ran, isTrue);
    expect(calls.single.arguments, 'HapticFeedbackType.mediumImpact');
  });

  test('wrapTap / wrapLongPress return null for null callbacks', () {
    expect(S1Haptics.wrapTap(null), isNull);
    expect(S1Haptics.wrapLongPress(null), isNull);
  });

  test('wrapRefresh fires light then runs refresh', () async {
    var ran = false;
    await S1Haptics.wrapRefresh(() async {
      ran = true;
    });
    await Future<void>.delayed(Duration.zero);
    expect(ran, isTrue);
    expect(calls.single.arguments, 'HapticFeedbackType.lightImpact');
  });
}
