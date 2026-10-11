import 'dart:io';

/// 覆盖更新交接：新进程启动早期把「已启动」写入旧进程指定的标记文件。
///
/// 标记文件路径由旧进程通过环境变量 [envName] 传入；写失败不致命
/// （旧进程会在超时后回滚），因此这里吞掉异常。
void reportUpdateStarted(String envName) {
  final path = Platform.environment[envName];
  if (path == null || path.isEmpty) return;
  try {
    File(path).writeAsStringSync('$pid');
  } on Object {
    // best-effort：写不进去则由旧进程超时回滚。
  }
}
