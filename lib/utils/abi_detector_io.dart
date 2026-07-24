import 'dart:ffi';

/// 返回当前设备的 Android / OS CPU 架构名称（如 `"arm64-v8a"`）。
///
/// 仅 native 平台有效；若未列入映射则返回 `null`。
String? currentAbi() {
  return switch (Abi.current()) {
    Abi.androidArm64 => 'arm64-v8a',
    Abi.androidArm => 'armeabi-v7a',
    Abi.androidX64 => 'x86_64',
    _ => null,
  };
}
