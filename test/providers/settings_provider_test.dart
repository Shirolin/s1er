import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s1er/config/constants.dart';
import 'package:s1er/models/image_load_policy.dart';
import 'package:s1er/models/share_image_format.dart';
import 'package:s1er/providers/settings_provider.dart';
import 'package:s1er/services/settings_store.dart';
import 'package:s1er/theme/app_theme.dart';
import '../helpers/test_local_data.dart';

void main() {
  late SettingsStore store;
  late dynamic db;

  setUp(() async {
    final opened = await openTestLocalData();
    db = opened.$1;
    store = opened.$2.settings;
  });

  tearDown(() async {
    await db.close();
  });

  test('resetAppearanceSettings restores defaults only for appearance prefs',
      () {
    final container = ProviderContainer(
      overrides: [
        settingsProvider.overrideWith(
          () => SettingsNotifier(
            store: store,
            initial: const AppSettings(
              themeMode: 'dark',
              themeColor: 'green',
              showImages: false,
              recordReadingHistory: false,
              fontSize: 18,
              collapsedForums: {'42'},
            ),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    container.read(settingsProvider.notifier).resetAppearanceSettings();
    final state = container.read(settingsProvider);

    expect(state.themeMode, 'system');
    expect(state.themeColor, 'sand');
    expect(state.showImages, isTrue);
    expect(state.imageLoadPolicy, ImageLoadPolicy.always);
    expect(state.avatarLoadPolicy, ImageLoadPolicy.always);
    expect(state.maxImagesPerPost, S1Constants.defaultMaxImagesPerPost);
    expect(state.imageCacheLimitMb, S1Constants.defaultImageCacheLimitMb);
    expect(state.recordReadingHistory, isTrue);
    expect(state.fontSize, S1Typography.defaultBodySize);
    expect(state.collapsedForums, const {'42'});
    expect(state.shareImageFormat, ShareImageFormat.webp);
    expect(state.sharePixelRatio, 1.5);
  });

  test('setRecordReadingHistory persists to settings store', () async {
    final container = ProviderContainer(
      overrides: [
        settingsProvider.overrideWith(
          () => SettingsNotifier(store: store, initial: const AppSettings()),
        ),
      ],
    );
    addTearDown(container.dispose);

    container.read(settingsProvider.notifier).setRecordReadingHistory(false);

    expect(container.read(settingsProvider).recordReadingHistory, isFalse);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(store.get<bool>('recordReadingHistory'), isFalse);
  });

  test('legacy custom theme colors are normalized to the default preset', () {
    store.put('themeColor', '#2B2930');
    final container = ProviderContainer(
      overrides: [
        settingsProvider.overrideWith(() => SettingsNotifier(store: store)),
      ],
    );
    addTearDown(container.dispose);

    expect(container.read(settingsProvider).themeColor, 'sand');
    expect(store.get<String>('themeColor'), 'sand');

    container.read(settingsProvider.notifier).setThemeColor('#141218');
    expect(container.read(settingsProvider).themeColor, 'sand');
  });

  test('setImageLoadPolicy persists to settings store', () async {
    final container = ProviderContainer(
      overrides: [
        settingsProvider.overrideWith(
          () => SettingsNotifier(store: store, initial: const AppSettings()),
        ),
      ],
    );
    addTearDown(container.dispose);

    container
        .read(settingsProvider.notifier)
        .setImageLoadPolicy(ImageLoadPolicy.manual);

    expect(
      container.read(settingsProvider).imageLoadPolicy,
      ImageLoadPolicy.manual,
    );
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(store.get<String>('imageLoadPolicy'), 'manual');
  });

  test('setAvatarLoadPolicy and cache settings persist', () async {
    final container = ProviderContainer(
      overrides: [
        settingsProvider.overrideWith(
          () => SettingsNotifier(store: store, initial: const AppSettings()),
        ),
      ],
    );
    addTearDown(container.dispose);

    container
        .read(settingsProvider.notifier)
        .setAvatarLoadPolicy(ImageLoadPolicy.wifiOnly);
    container.read(settingsProvider.notifier).setMaxImagesPerPost(5);
    container.read(settingsProvider.notifier).setImageCacheLimitMb(512);

    expect(
      container.read(settingsProvider).avatarLoadPolicy,
      ImageLoadPolicy.wifiOnly,
    );
    expect(container.read(settingsProvider).maxImagesPerPost, 5);
    expect(container.read(settingsProvider).imageCacheLimitMb, 512);

    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(store.get<String>('avatarLoadPolicy'), 'wifiOnly');
    expect(store.get<int>('maxImagesPerPost'), 5);
    expect(store.get<int>('imageCacheLimitMb'), 512);
  });

  test('setShowImages with same value does not notify listeners', () {
    final container = ProviderContainer(
      overrides: [
        settingsProvider.overrideWith(
          () => SettingsNotifier(
            store: store,
            initial: const AppSettings(showImages: true),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    var notifications = 0;
    container.listen(
      settingsProvider,
      (_, __) => notifications++,
      fireImmediately: true,
    );
    notifications = 0;

    container.read(settingsProvider.notifier).setShowImages(true);

    expect(notifications, 0);
    expect(container.read(settingsProvider).showImages, isTrue);
  });

  test('setShareImageFormat persists to settings store', () async {
    final container = ProviderContainer(
      overrides: [
        settingsProvider.overrideWith(
          () => SettingsNotifier(store: store, initial: const AppSettings()),
        ),
      ],
    );
    addTearDown(container.dispose);

    container
        .read(settingsProvider.notifier)
        .setShareImageFormat(ShareImageFormat.png);

    expect(
      container.read(settingsProvider).shareImageFormat,
      ShareImageFormat.png,
    );
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(store.get<String>('shareImageFormat'), 'png');
  });

  test('setSharePixelRatio snaps to 1.5/2/3 and persists', () async {
    final container = ProviderContainer(
      overrides: [
        settingsProvider.overrideWith(
          () => SettingsNotifier(store: store, initial: const AppSettings()),
        ),
      ],
    );
    addTearDown(container.dispose);

    container.read(settingsProvider.notifier).setSharePixelRatio(5);
    expect(container.read(settingsProvider).sharePixelRatio, 3.0);

    container.read(settingsProvider.notifier).setSharePixelRatio(1);
    expect(container.read(settingsProvider).sharePixelRatio, 1.5);

    container.read(settingsProvider.notifier).setSharePixelRatio(2);
    expect(container.read(settingsProvider).sharePixelRatio, 2.0);

    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(store.get<Object>('sharePixelRatio'), 2.0);
  });

  test('setPostSignatureCustom persists to settings store', () async {
    final container = ProviderContainer(
      overrides: [
        settingsProvider.overrideWith(
          () => SettingsNotifier(store: store, initial: const AppSettings()),
        ),
      ],
    );
    addTearDown(container.dispose);

    container.read(settingsProvider.notifier).setPostSignatureCustom('摸鱼');
    container.read(settingsProvider.notifier).setPostSignatureEnabled(false);
    container.read(settingsProvider.notifier).setPostSignatureShowDevice(false);

    final state = container.read(settingsProvider);
    expect(state.postSignatureCustom, '摸鱼');
    expect(state.postSignatureEnabled, isFalse);
    expect(state.postSignatureShowDevice, isFalse);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(store.get<String>('postSignatureCustom'), '摸鱼');
    expect(store.get<bool>('postSignatureEnabled'), isFalse);
    expect(store.get<bool>('postSignatureShowDevice'), isFalse);
  });
}
