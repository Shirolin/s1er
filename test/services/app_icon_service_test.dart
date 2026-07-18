import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s1er/services/app_icon_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.stage1st.s1er/app_icon');

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('unsupported platform is no-op for setIcon', () async {
    final service = AppIconService(supportedOverride: false);
    expect(service.isSupported, isFalse);
    await service.setIcon('white');
    expect(await service.getCurrentIconId(), isNull);
  });

  test('getCurrentIconId normalizes empty to black', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'getIcon') return '';
      return null;
    });

    final service = AppIconService(supportedOverride: true);
    expect(await service.getCurrentIconId(), 'black');
  });

  test('setIcon forwards normalized id', () async {
    String? received;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'setIcon') {
        received = (call.arguments as Map)['id'] as String?;
      }
      return null;
    });

    final service = AppIconService(supportedOverride: true);
    await service.setIcon('nope');
    expect(received, 'black');
  });

  test('setIcon rethrows PlatformException', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      throw PlatformException(code: 'set_failed', message: 'boom');
    });

    final service = AppIconService(supportedOverride: true);
    expect(
      () => service.setIcon('white'),
      throwsA(isA<PlatformException>()),
    );
  });
}
