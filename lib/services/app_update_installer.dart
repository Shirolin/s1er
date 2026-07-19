import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/app_exceptions.dart';

/// Android APK 安装（MethodChannel → FileProvider）。
class AppUpdateInstaller {
  AppUpdateInstaller({
    MethodChannel? channel,
    TargetPlatform? platform,
  })  : _channel =
            channel ?? const MethodChannel('com.stage1st.s1er/apk_installer'),
        _platform = platform ?? defaultTargetPlatform;

  final MethodChannel _channel;
  final TargetPlatform _platform;

  bool get isSupported => !kIsWeb && _platform == TargetPlatform.android;

  Future<bool> canInstallPackages() async {
    if (!isSupported) return false;
    final result = await _channel.invokeMethod<bool>('canInstallPackages');
    return result ?? false;
  }

  Future<void> openInstallPermissionSettings() async {
    if (!isSupported) {
      throw const UpdateCheckException('当前平台不支持安装权限设置');
    }
    await _channel.invokeMethod<void>('openInstallPermissionSettings');
  }

  Future<void> installApk(String filePath) async {
    if (!isSupported) {
      throw const UpdateCheckException('当前平台不支持应用内安装');
    }
    final path = filePath.trim();
    if (path.isEmpty) {
      throw const UpdateCheckException('安装包路径无效');
    }
    try {
      await _channel.invokeMethod<void>('installApk', {'path': path});
    } on PlatformException catch (e) {
      throw UpdateCheckException(
        e.message?.trim().isNotEmpty == true ? e.message!.trim() : '无法调起安装',
        e,
      );
    }
  }
}
