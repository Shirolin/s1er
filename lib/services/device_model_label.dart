import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';

import 'talker.dart';

/// 小尾巴用细机型标签；失败时回退平台粗名。
class DeviceModelLabel {
  DeviceModelLabel({DeviceInfoPlugin? plugin})
      : _plugin = plugin ?? DeviceInfoPlugin();

  final DeviceInfoPlugin _plugin;

  /// 常见 iOS `utsname.machine` → 营销名（[modelName] 为空时的后备）。
  @visibleForTesting
  static const Map<String, String> iosMachineMarketingNames = {
    'iPhone14,2': 'iPhone 13 Pro',
    'iPhone14,3': 'iPhone 13 Pro Max',
    'iPhone14,4': 'iPhone 13 mini',
    'iPhone14,5': 'iPhone 13',
    'iPhone14,7': 'iPhone 14',
    'iPhone14,8': 'iPhone 14 Plus',
    'iPhone15,2': 'iPhone 14 Pro',
    'iPhone15,3': 'iPhone 14 Pro Max',
    'iPhone15,4': 'iPhone 15',
    'iPhone15,5': 'iPhone 15 Plus',
    'iPhone16,1': 'iPhone 15 Pro',
    'iPhone16,2': 'iPhone 15 Pro Max',
    'iPhone17,1': 'iPhone 16 Pro',
    'iPhone17,2': 'iPhone 16 Pro Max',
    'iPhone17,3': 'iPhone 16',
    'iPhone17,4': 'iPhone 16 Plus',
    'iPad13,4': 'iPad Pro 11-inch',
    'iPad13,8': 'iPad Pro 12.9-inch',
    'iPad14,1': 'iPad mini',
    'iPad14,3': 'iPad Pro 11-inch',
    'iPad14,5': 'iPad Pro 12.9-inch',
  };

  Future<String> resolve() async {
    try {
      if (kIsWeb) {
        return _fromWeb(await _plugin.webBrowserInfo);
      }
      switch (defaultTargetPlatform) {
        case TargetPlatform.android:
          return _fromAndroid(await _plugin.androidInfo);
        case TargetPlatform.iOS:
          return _fromIos(await _plugin.iosInfo);
        case TargetPlatform.windows:
          return _fromWindows(await _plugin.windowsInfo);
        case TargetPlatform.macOS:
          return _fromMacOs(await _plugin.macOsInfo);
        case TargetPlatform.linux:
          return _fromLinux(await _plugin.linuxInfo);
        case TargetPlatform.fuchsia:
          return coarseFallback();
      }
    } catch (e, st) {
      talker.handle(e, st, 'Resolve device model label failed');
      return coarseFallback();
    }
  }

  static String coarseFallback() {
    if (kIsWeb) return 'Web';
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'Android';
      case TargetPlatform.iOS:
        return 'iOS';
      case TargetPlatform.windows:
        return 'Windows';
      case TargetPlatform.macOS:
        return 'macOS';
      case TargetPlatform.linux:
        return 'Linux';
      case TargetPlatform.fuchsia:
        return 'Fuchsia';
    }
  }

  static String _fromAndroid(AndroidDeviceInfo info) {
    final model = info.model.trim();
    if (model.isNotEmpty) return model;
    final brand = info.brand.trim();
    if (brand.isNotEmpty) return brand;
    return 'Android';
  }

  static String _fromIos(IosDeviceInfo info) {
    final marketing = info.modelName.trim();
    if (marketing.isNotEmpty) return marketing;

    final machine = info.utsname.machine.trim();
    final mapped = iosMachineMarketingNames[machine];
    if (mapped != null) return mapped;

    final model = info.model.trim();
    if (model.isNotEmpty) return model;
    if (machine.isNotEmpty) {
      if (machine.startsWith('iPhone')) return 'iPhone';
      if (machine.startsWith('iPad')) return 'iPad';
      return machine;
    }
    return 'iOS';
  }

  static String _fromWindows(WindowsDeviceInfo info) {
    final product = info.productName.trim();
    if (product.isNotEmpty) return product;
    return 'Windows';
  }

  static String _fromMacOs(MacOsDeviceInfo info) {
    final marketing = info.modelName.trim();
    if (marketing.isNotEmpty) return marketing;
    final model = info.model.trim();
    if (model.isNotEmpty) return model;
    return 'macOS';
  }

  static String _fromLinux(LinuxDeviceInfo info) {
    final pretty = info.prettyName.trim();
    if (pretty.isNotEmpty) return _truncate(pretty, 40);
    final name = info.name.trim();
    if (name.isNotEmpty) return name;
    return 'Linux';
  }

  static String _fromWeb(WebBrowserInfo info) {
    switch (info.browserName) {
      case BrowserName.firefox:
        return 'Firefox';
      case BrowserName.samsungInternet:
        return 'Samsung Internet';
      case BrowserName.opera:
        return 'Opera';
      case BrowserName.msie:
        return 'Internet Explorer';
      case BrowserName.edge:
        return 'Edge';
      case BrowserName.chrome:
        return 'Chrome';
      case BrowserName.safari:
        return 'Safari';
      case BrowserName.unknown:
        final agent = info.appName?.trim();
        if (agent != null && agent.isNotEmpty) return agent;
        return 'Web';
    }
  }

  static String _truncate(String value, int max) {
    if (value.length <= max) return value;
    return value.substring(0, max);
  }
}
