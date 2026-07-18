import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../config/app_icon_catalog.dart';
import 'talker.dart';

/// Switches the home-screen launcher icon on Android / iOS.
///
/// Web and desktop are unsupported ([isSupported] is false).
class AppIconService {
  AppIconService({
    MethodChannel? channel,
    bool? supportedOverride,
  })  : _channel = channel ?? const MethodChannel(_channelName),
        _supportedOverride = supportedOverride;

  static const _channelName = 'com.stage1st.s1er/app_icon';

  static final AppIconService instance = AppIconService();

  final MethodChannel _channel;
  final bool? _supportedOverride;

  bool get isSupported {
    if (_supportedOverride != null) return _supportedOverride;
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  /// Current launcher icon id, or null when unsupported / unknown.
  Future<String?> getCurrentIconId() async {
    if (!isSupported) return null;
    try {
      final result = await _channel.invokeMethod<String>('getIcon');
      if (result == null || result.isEmpty) {
        return AppIconCatalog.defaultId;
      }
      return AppIconCatalog.normalize(result);
    } on PlatformException catch (e, st) {
      talker.handle(e, st, 'AppIconService.getCurrentIconId failed');
      return null;
    } on MissingPluginException catch (e, st) {
      talker.handle(e, st, 'AppIconService.getCurrentIconId missing plugin');
      return null;
    }
  }

  /// Applies [id] on the native launcher. No-op when unsupported.
  Future<void> setIcon(String id) async {
    if (!isSupported) return;
    final normalized = AppIconCatalog.normalize(id);
    try {
      await _channel.invokeMethod<void>('setIcon', {'id': normalized});
    } on PlatformException catch (e, st) {
      talker.handle(e, st, 'AppIconService.setIcon($normalized) failed');
      rethrow;
    } on MissingPluginException catch (e, st) {
      talker.handle(e, st, 'AppIconService.setIcon missing plugin');
      rethrow;
    }
  }
}
