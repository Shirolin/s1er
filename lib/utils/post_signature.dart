import '../config/constants.dart';

/// 发帖/回复小尾巴组装（纯函数，提交时追加，不进输入框）。
///
/// 落款观感：破折号起头、小字灰色、
/// 「——来自 {机型} 上的 {客户端链接}」。
class PostSignature {
  PostSignature._();

  static const int maxCustomLength = 20;

  /// 去空白、去换行、剥离 `[]`，再截断到 [maxCustomLength]。
  static String sanitizeCustom(String raw) {
    final oneLine = raw
        .replaceAll(RegExp(r'[\r\n]+'), ' ')
        .replaceAll('[', '')
        .replaceAll(']', '')
        .trim();
    if (oneLine.length <= maxCustomLength) return oneLine;
    return oneLine.substring(0, maxCustomLength);
  }

  /// 设置页预览用：去掉 BBCode，只保留可见文案。
  static String buildDisplay({
    required bool enabled,
    required bool showDevice,
    required String custom,
    String appName = S1Constants.appName,
    String? deviceLabel,
  }) {
    if (!enabled) return '';
    final client = '$appName 客户端';
    return _plainLine(
      custom: custom,
      showDevice: showDevice,
      deviceLabel: deviceLabel,
      clientLabel: client,
    );
  }

  /// 组装尾巴 BBCode；[enabled] 为 false 时返回空串。
  static String build({
    required bool enabled,
    required bool showDevice,
    required String custom,
    String appName = S1Constants.appName,
    String downloadUrl = S1Constants.downloadUrl,
    String? deviceLabel,
  }) {
    if (!enabled) return '';

    final clientLink = '[url=$downloadUrl]$appName 客户端[/url]';
    final line = _plainLine(
      custom: custom,
      showDevice: showDevice,
      deviceLabel: deviceLabel,
      clientLabel: clientLink,
    );
    // size=1 / gray：论坛侧像落款；本客户端预览同样解析。
    return '[size=1][color=gray]$line[/color][/size]';
  }

  /// 在用户正文末尾追加小尾巴（中间空一行）。
  static String appendIfEnabled(
    String userMessage, {
    required bool enabled,
    required bool showDevice,
    required String custom,
    String appName = S1Constants.appName,
    String downloadUrl = S1Constants.downloadUrl,
    String? deviceLabel,
  }) {
    final sig = build(
      enabled: enabled,
      showDevice: showDevice,
      custom: custom,
      appName: appName,
      downloadUrl: downloadUrl,
      deviceLabel: deviceLabel,
    );
    final body = userMessage.trimRight();
    if (sig.isEmpty) return body;
    if (body.isEmpty) return sig;
    return '$body\n\n$sig';
  }

  /// 可见落款行（[clientLabel] 可为纯文本或已包好的 `[url]…[/url]`）。
  static String _plainLine({
    required String custom,
    required bool showDevice,
    required String? deviceLabel,
    required String clientLabel,
  }) {
    final sanitized = sanitizeCustom(custom);
    final device = showDevice ? (deviceLabel?.trim() ?? '') : '';

    final String core;
    if (device.isNotEmpty) {
      core = '来自 $device 上的 $clientLabel';
    } else {
      core = '来自 $clientLabel';
    }

    if (sanitized.isEmpty) return '——$core';
    return '——$sanitized · $core';
  }
}
