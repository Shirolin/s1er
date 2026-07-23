/// 应用升级清单（远端 `latest.json`）。
class AppUpdateManifest {
  const AppUpdateManifest({
    required this.latest,
    required this.minSupported,
    required this.notes,
    required this.publishedAt,
    required this.channels,
  });

  factory AppUpdateManifest.fromJson(Map<String, dynamic> json) {
    final latest = (json['latest']?.toString() ?? '').trim();
    if (latest.isEmpty) {
      throw const FormatException('latest is required');
    }
    final minSupported = (json['minSupported']?.toString() ?? latest).trim();
    final channelsRaw = json['channels'];
    final channelsMap = channelsRaw is Map
        ? Map<String, dynamic>.from(channelsRaw)
        : <String, dynamic>{};

    return AppUpdateManifest(
      latest: latest,
      minSupported: minSupported.isEmpty ? latest : minSupported,
      notes: (json['notes']?.toString() ?? '').trim(),
      publishedAt: (json['publishedAt']?.toString() ?? '').trim(),
      channels: AppUpdateChannels.fromJson(channelsMap),
    );
  }

  final String latest;
  final String minSupported;
  final String notes;
  final String publishedAt;
  final AppUpdateChannels channels;
}

class AppUpdateChannels {
  const AppUpdateChannels({
    required this.github,
    this.androidApk,
    this.androidApks,
    this.androidNetdisk,
    this.netdiskHint,
    this.windows,
    this.linux,
    this.macos,
    this.play,
  });

  factory AppUpdateChannels.fromJson(Map<String, dynamic> json) {
    String? optionalUrl(String key) {
      final raw = json[key]?.toString().trim();
      if (raw == null || raw.isEmpty) return null;
      return raw;
    }

    String? optionalText(String key) {
      final raw = json[key]?.toString().trim();
      if (raw == null || raw.isEmpty) return null;
      return raw;
    }

    final github = optionalUrl('github') ??
        'https://github.com/Shirolin/s1er/releases/latest';

    return AppUpdateChannels(
      github: github,
      androidApk: optionalUrl('androidApk'),
      androidApks: _parseAndroidApks(json['androidApks']),
      androidNetdisk: optionalUrl('androidNetdisk'),
      netdiskHint: optionalText('netdiskHint'),
      windows: optionalUrl('windows'),
      linux: optionalUrl('linux'),
      macos: optionalUrl('macos'),
      play: optionalUrl('play'),
    );
  }

  /// 分架构 APK 直链；键为 ABI（如 `arm64-v8a`），与 Flutter `--split-per-abi` 一致。
  static Map<String, String>? _parseAndroidApks(Object? raw) {
    if (raw is! Map) return null;
    final out = <String, String>{};
    for (final entry in raw.entries) {
      final abi = entry.key.toString().trim();
      final url = entry.value?.toString().trim() ?? '';
      if (abi.isEmpty || url.isEmpty) continue;
      out[abi] = url;
    }
    if (out.isEmpty) return null;
    return Map<String, String>.unmodifiable(out);
  }

  final String github;

  /// Universal（全 ABI）APK；旧客户端与分架构失败时的回退。
  final String? androidApk;

  /// 可选分架构直链；缺省时仅用 [androidApk]。
  final Map<String, String>? androidApks;

  /// 国内网盘分享链接（仅外链打开，不进 APK 下载白名单）。
  final String? androidNetdisk;

  /// 提取码等说明（可空）。
  final String? netdiskHint;
  final String? windows;
  final String? linux;
  final String? macos;
  final String? play;
}
