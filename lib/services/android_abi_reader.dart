import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';

import 'talker.dart';

/// 读取本机 Android `supportedAbis`（有序，首位为主 ABI）。
///
/// 非 Android / Web / 失败时返回空列表（调用方仅用 universal）。
class AndroidAbiReader {
  AndroidAbiReader({
    DeviceInfoPlugin? plugin,
    Future<List<String>> Function()? readAbis,
  })  : _plugin = plugin ?? DeviceInfoPlugin(),
        _readAbis = readAbis;

  final DeviceInfoPlugin _plugin;
  final Future<List<String>> Function()? _readAbis;

  Future<List<String>> supportedAbis() async {
    if (_readAbis != null) {
      return List<String>.unmodifiable(await _readAbis());
    }
    if (kIsWeb) return const [];
    if (defaultTargetPlatform != TargetPlatform.android) return const [];
    try {
      final info = await _plugin.androidInfo;
      return List<String>.unmodifiable(
        info.supportedAbis
            .map((a) => a.trim())
            .where((a) => a.isNotEmpty)
            .toList(growable: false),
      );
    } on Object catch (e, st) {
      talker.handle(e, st, 'Read Android supportedAbis failed');
      return const [];
    }
  }
}
