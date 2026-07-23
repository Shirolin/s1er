import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s1er/config/constants.dart';
import 'package:s1er/models/image_load_policy.dart';
import 'package:s1er/models/list_density.dart';
import 'package:s1er/models/share_image_format.dart';
import 'package:s1er/providers/settings_provider.dart';
import 'package:s1er/services/app_icon_service.dart';
import 'package:s1er/services/settings_store.dart';
import 'package:s1er/theme/app_theme.dart';
import 'package:s1er/theme/s1_haptics.dart';
import '../helpers/test_local_data.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
              appIcon: 'white',
              showImages: false,
              recordReadingHistory: false,
              fontSize: 18,
              collapsedForums: {'42'},
              hiddenForums: {'7'},
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
    expect(state.appIcon, 'black');
    expect(state.showImages, isTrue);
    expect(state.imageLoadPolicy, ImageLoadPolicy.always);
    expect(state.avatarLoadPolicy, ImageLoadPolicy.always);
    expect(state.maxImagesPerPost, S1Constants.defaultMaxImagesPerPost);
    expect(state.imageCacheLimitMb, S1Constants.defaultImageCacheLimitMb);
    expect(state.recordReadingHistory, isTrue);
    expect(state.fontSize, S1Typography.defaultBodySize);
    expect(state.collapsedForums, const {'42'});
    expect(state.hiddenForums, const {'7'});
    expect(state.shareImageFormat, ShareImageFormat.webp);
    expect(state.sharePixelRatio, 1.5);
    expect(state.threadListDensity, ListDensity.standard);
    expect(state.postListDensity, ListDensity.standard);
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

  test('hideForum and unhideForum persist to settings store', () async {
    final container = ProviderContainer(
      overrides: [
        settingsProvider.overrideWith(
          () => SettingsNotifier(store: store, initial: const AppSettings()),
        ),
      ],
    );
    addTearDown(container.dispose);

    final notifier = container.read(settingsProvider.notifier);
    notifier.hideForum('75');
    expect(container.read(settingsProvider).hiddenForums, const {'75'});
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(store.get<List>('hiddenForums'), ['75']);

    notifier.hideForum('6');
    notifier.unhideForum('75');
    expect(container.read(settingsProvider).hiddenForums, const {'6'});
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(store.get<List>('hiddenForums'), ['6']);

    notifier.clearHiddenForums();
    expect(container.read(settingsProvider).hiddenForums, isEmpty);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(store.get<List>('hiddenForums'), isEmpty);
  });

  test('setHapticsEnabled persists and syncs S1Haptics.enabled', () async {
    S1Haptics.enabled = true;
    final container = ProviderContainer(
      overrides: [
        settingsProvider.overrideWith(
          () => SettingsNotifier(store: store, initial: const AppSettings()),
        ),
      ],
    );
    addTearDown(container.dispose);

    container.read(settingsProvider.notifier).setHapticsEnabled(false);

    expect(container.read(settingsProvider).hapticsEnabled, isFalse);
    expect(S1Haptics.enabled, isFalse);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(store.get<bool>('hapticsEnabled'), isFalse);

    container.read(settingsProvider.notifier).setHapticsEnabled(true);
    expect(S1Haptics.enabled, isTrue);
  });

  test('setThreadListDensity and setPostListDensity persist independently',
      () async {
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
        .setThreadListDensity(ListDensity.compact);
    expect(
      container.read(settingsProvider).threadListDensity,
      ListDensity.compact,
    );
    expect(
      container.read(settingsProvider).postListDensity,
      ListDensity.standard,
    );
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(store.get<String>('threadListDensity'), 'compact');
    expect(store.get<String>('postListDensity'), isNull);

    container
        .read(settingsProvider.notifier)
        .setPostListDensity(ListDensity.compact);
    expect(
      container.read(settingsProvider).postListDensity,
      ListDensity.compact,
    );
    expect(
      container.read(settingsProvider).threadListDensity,
      ListDensity.compact,
    );
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(store.get<String>('postListDensity'), 'compact');
  });

  test('resetAppearanceSettings restores list density defaults', () {
    final container = ProviderContainer(
      overrides: [
        settingsProvider.overrideWith(
          () => SettingsNotifier(
            store: store,
            initial: const AppSettings(
              threadListDensity: ListDensity.compact,
              postListDensity: ListDensity.compact,
            ),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    container.read(settingsProvider.notifier).resetAppearanceSettings();
    final state = container.read(settingsProvider);
    expect(state.threadListDensity, ListDensity.standard);
    expect(state.postListDensity, ListDensity.standard);
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

  test('setAppIcon persists and rolls back on native failure', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    const channel = MethodChannel('com.stage1st.s1er/app_icon');
    var fail = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (fail && call.method == 'setIcon') {
        throw PlatformException(code: 'set_failed', message: 'nope');
      }
      return null;
    });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    final service = AppIconService(supportedOverride: true);
    final container = ProviderContainer(
      overrides: [
        appIconServiceProvider.overrideWithValue(service),
        settingsProvider.overrideWith(
          () => SettingsNotifier(
            store: store,
            initial: const AppSettings(),
            appIconService: service,
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    final ok =
        await container.read(settingsProvider.notifier).setAppIcon('white');
    expect(ok, isTrue);
    expect(container.read(settingsProvider).appIcon, 'white');
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(store.get<String>('appIcon'), 'white');

    fail = true;
    final failed =
        await container.read(settingsProvider.notifier).setAppIcon('black');
    expect(failed, isFalse);
    expect(container.read(settingsProvider).appIcon, 'white');
    expect(store.get<String>('appIcon'), 'white');
  });
}
