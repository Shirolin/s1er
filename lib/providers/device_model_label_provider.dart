import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/device_model_label.dart';

/// 小尾巴预览/提交用的细机型标签。
final deviceModelLabelProvider = FutureProvider<String>((ref) async {
  return DeviceModelLabel().resolve();
});

/// Provider 未就绪时的粗平台名（与 [DeviceModelLabel.coarseFallback] 一致）。
String deviceModelLabelFallback() => DeviceModelLabel.coarseFallback();
