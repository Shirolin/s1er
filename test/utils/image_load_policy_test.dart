import 'package:flutter_test/flutter_test.dart';
import 'package:s1er/models/image_load_policy.dart';
import 'package:s1er/utils/image_load_policy.dart';

void main() {
  group('shouldAutoLoadInlineImages', () {
    test('returns false when showImages is off', () {
      expect(
        shouldAutoLoadInlineImages(
          showImages: false,
          policy: ImageLoadPolicy.always,
          wifiConnected: true,
          userRequested: false,
        ),
        isFalse,
      );
    });

    test('always policy loads on any network', () {
      expect(
        shouldAutoLoadInlineImages(
          showImages: true,
          policy: ImageLoadPolicy.always,
          wifiConnected: false,
          userRequested: false,
        ),
        isTrue,
      );
    });

    test('wifiOnly requires wifi unless user requested', () {
      expect(
        shouldAutoLoadInlineImages(
          showImages: true,
          policy: ImageLoadPolicy.wifiOnly,
          wifiConnected: false,
          userRequested: false,
        ),
        isFalse,
      );
      expect(
        shouldAutoLoadInlineImages(
          showImages: true,
          policy: ImageLoadPolicy.wifiOnly,
          wifiConnected: true,
          userRequested: false,
        ),
        isTrue,
      );
      expect(
        shouldAutoLoadInlineImages(
          showImages: true,
          policy: ImageLoadPolicy.wifiOnly,
          wifiConnected: false,
          userRequested: true,
        ),
        isTrue,
      );
    });

    test('manual never auto-loads unless user requested', () {
      expect(
        shouldAutoLoadInlineImages(
          showImages: true,
          policy: ImageLoadPolicy.manual,
          wifiConnected: true,
          userRequested: false,
        ),
        isFalse,
      );
      expect(
        shouldAutoLoadInlineImages(
          showImages: true,
          policy: ImageLoadPolicy.manual,
          wifiConnected: false,
          userRequested: true,
        ),
        isTrue,
      );
    });
  });

  group('ImageLoadPolicy storage', () {
    test('round-trips backup keys', () {
      expect(
        ImageLoadPolicy.fromBackup('wifi_only').storageKey,
        'wifiOnly',
      );
      expect(
        ImageLoadPolicy.wifiOnly.backupKey,
        'wifi_only',
      );
    });
  });
}
