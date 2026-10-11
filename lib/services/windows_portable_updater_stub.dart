import '../models/app_exceptions.dart';

/// Web / 无 IO：不支持 Windows 绿色包覆盖更新。
class WindowsPortableUpdater {
  WindowsPortableUpdater({
    String Function()? resolvedExecutable,
    Future<dynamic> Function()? temporaryDirectory,
    Future<void> Function(String from, String to)? renameFile,
    Future<void> Function(
      String executable,
      String workingDirectory,
      String markerPath,
    )? relaunch,
    void Function(String directory)? setCurrentDirectory,
    void Function(int code)? exitApp,
    Duration? startTimeout,
  });

  Future<void> applyDownloadedZip(String zipPath) async {
    throw const UpdateCheckException('当前平台不支持覆盖更新');
  }
}
