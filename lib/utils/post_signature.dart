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

  /// 剥离文末客户端小尾巴（`[size=1][color=gray]——…[/color][/size]`）。
  ///
  /// 编辑回填时用：输入框不展示旧尾巴，提交再按当前设置追加。
  static String stripTrailing(String message) {
    return message.replaceFirst(_trailingSignaturePattern, '').trimRight();
  }

  static bool hasTrailing(String message) =>
      _trailingSignaturePattern.hasMatch(message);

  /// 分享卡渲染前分离文末客户端小尾巴，返回正文与纯文本落款。
  ///
  /// 兼容本客户端 [build] 产出及论坛助手等常见文末落款；
  /// 若剥离后正文为空，则保留原文不剥离，避免整楼空白。
  /// 当落款是本客户端尾巴时，去掉与页脚重复的「来自 S1er 客户端」，
  /// 仅保留机型或自定义句（若无增量信息则返回 `signature: null`）。
  static ({String body, String? signature}) extractForShare(String message) {
    final trimmed = message.trimRight();
    if (trimmed.isEmpty) return (body: message, signature: null);

    for (final pattern in _shareTrailingPatterns) {
      final match = pattern.firstMatch(trimmed);
      if (match == null) continue;
      final rawSig = match.group(0)!;
      if (_nonSignatureBlockTag.hasMatch(rawSig)) continue;
      final body = _trimTrailingLineBreaks(trimmed.substring(0, match.start));
      if (body.isEmpty) return (body: message, signature: null);
      final plainSig = _stripMarkupForSignature(rawSig);
      if (plainSig.isEmpty || plainSig.length > 120) continue;
      return (body: body, signature: _dedupeSelfClientForShare(plainSig));
    }
    return (body: message, signature: null);
  }

  static String _trimTrailingLineBreaks(String raw) {
    var out = raw.trimRight();
    final trailingBr = RegExp(r'(?:<br\s*/?>|\s)+$', caseSensitive: false);
    out = out.replaceFirst(trailingBr, '');
    return out.trimRight();
  }

  static String? _dedupeSelfClientForShare(String plainSig) {
    const clientLabel = '${S1Constants.appName} 客户端';
    if (!plainSig.endsWith(clientLabel)) return plainSig;

    // 「——摸鱼 · 来自 Pixel 8 上的 S1er 客户端」->「——摸鱼 · 来自 Pixel 8」
    // 「——来自 iPhone 上的 S1er 客户端」->「——来自 iPhone」
    // 「——摸鱼 · 来自 S1er 客户端」->「——摸鱼」
    // 「——来自 S1er 客户端」-> null（完全与页脚重复）
    final withoutOnClient = plainSig.replaceFirst(
      RegExp('\\s+上的\\s+${RegExp.escape(clientLabel)}\$'),
      '',
    );
    if (withoutOnClient != plainSig) return withoutOnClient;

    final withoutCustomClient = plainSig.replaceFirst(
      RegExp('\\s*·\\s*来自\\s+${RegExp.escape(clientLabel)}\$'),
      '',
    );
    if (withoutCustomClient != plainSig) return withoutCustomClient;

    if (RegExp('^——\\s*来自\\s+${RegExp.escape(clientLabel)}\$')
        .hasMatch(plainSig)) {
      return null;
    }
    return plainSig;
  }

  static String _stripMarkupForSignature(String raw) {
    var text = raw.trim();
    text = text.replaceAllMapped(
      RegExp(
        r'\[url=[^\]]*\](.*?)\[/url\]',
        caseSensitive: false,
        dotAll: true,
      ),
      (m) => m.group(1) ?? '',
    );
    text = text.replaceAllMapped(
      RegExp(
        r'<a\b[^>]*>(.*?)</a>',
        caseSensitive: false,
        dotAll: true,
      ),
      (m) => m.group(1) ?? '',
    );
    text = text.replaceAll(
      RegExp(r'\[/?[a-z]+(?:=[^\]]*)?\]', caseSensitive: false),
      '',
    );
    text = text.replaceAll(RegExp(r'<[^>]+>'), '');
    text = text
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"');
    return text.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static final RegExp _nonSignatureBlockTag = RegExp(
    r'<(?:img|blockquote|div|table|pre)\b|\[(?:img|quote|code)\b',
    caseSensitive: false,
  );

  static const String _sep = r'(?:<br\s*/?>|\r?\n|\s){0,3}';
  static const String _clientKeywords =
      r'(?:客户端|论坛助手|S1Fun|S1er|S1Next|Stage1|Android|iPhone|iPad|Windows|macOS|Linux|HarmonyOS|Web|via\s+\S)';

  static final RegExp _trailingSignaturePattern = RegExp(
    r'(?:\r?\n){0,2}\[size=1\]\[color=gray\]——[\s\S]*?\[/color\]\[/size\]\s*$',
    caseSensitive: false,
  );

  static final List<RegExp> _shareTrailingPatterns = [
    _trailingSignaturePattern,
    // Discuz API 返回的 HTML <font size="1"><font color="gray">——...</font></font>
    RegExp(
      _sep +
          r'''<font\b[^>]*size=["']?1["']?[^>]*>(?:<font\b[^>]*color=["']?gray["']?[^>]*>)?——[\s\S]{2,350}?(?:</font>)?\s*</font>\s*$''',
      caseSensitive: false,
    ),
    // Discuz API 返回的外层 <a ...><font color="Gray">——...</font></a>
    RegExp(
      _sep +
          r'''<a\b[^>]*>(?:<font\b[^>]*>)?(?:——|发自|来自)[^\n<]{2,140}(?:</font>)?</a>\s*$''',
      caseSensitive: false,
    ),
    // 论坛助手 / S1Next 等常见 `[size=1][color=...]` 或 `[color=gray]` 包裹的末尾落款
    RegExp(
      r'(?:\r?\n){0,2}\[size=1\](?:\[color=[^\]]+\])?(?:——|发自|来自)[^\n]{2,140}(?:\[/color\])?\[/size\]\s*$',
      caseSensitive: false,
    ),
    RegExp(
      r'(?:\r?\n){0,2}\[color=gray\](?:——|发自|来自)[^\n]{2,140}\[/color\]\s*$',
      caseSensitive: false,
    ),
    // 外层由 [url=...] 包裹的末尾落款（如 [url=...][color=Gray]——来自论坛助手,iPhone[/color][/url]）
    RegExp(
      r'(?:\r?\n){0,2}\[url=[^\]]*\](?:\[size=1\])?(?:\[color=[^\]]+\])?(?:——|发自|来自)[^\n]{2,140}(?:\[/color\])?(?:\[/size\])?\[/url\]\s*$',
      caseSensitive: false,
    ),
    // 文末独立一行（BBCode 链接或纯文本 / HTML <a ...> 链接，如 S1Fun）
    // 须前置换行且含客户端/机型关键词，避免误伤「——来自鲁迅」等引用
    RegExp(
      r'(?:(?:\s*<br\s*/?>\s*)+|(?:\r?\n)+)\s*'
      r'(?:——\s*(?:来自|发自)|发自我的[^\n<]{0,40}via\s+)[^\r\n]{0,180}?'
      '$_clientKeywords'
      r'[^\r\n]{0,120}\s*$',
      caseSensitive: false,
    ),
  ];

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
