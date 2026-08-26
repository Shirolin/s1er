import '../models/app_exceptions.dart';

/// Web / 无 IO：不支持 Windows 绿色包覆盖更新。
class WindowsPortableUpdater {
  WindowsPortableUpdater({
    String Function()? resolvedExecutable,
    int Function()? currentPid,
    Future<dynamic> Function()? temporaryDirectory,
    Future<void> Function(String executable, List<String> arguments)?
        spawnDetached,
    void Function(int code)? exitApp,
    Duration? spawnSettle,
  });

  Future<void> applyDownloadedZip(String zipPath) async {
    throw const UpdateCheckException('当前平台不支持覆盖更新');
  }
}
