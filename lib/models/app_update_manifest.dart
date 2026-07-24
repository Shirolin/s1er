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
    this.androidArm64V8aApk,
    this.androidArmeabiV7aApk,
    this.androidX8664Apk,
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
      androidArm64V8aApk: optionalUrl('androidArm64V8aApk'),
      androidArmeabiV7aApk: optionalUrl('androidArmeabiV7aApk'),
      androidX8664Apk: optionalUrl('androidX8664Apk'),
      androidNetdisk: optionalUrl('androidNetdisk'),
      netdiskHint: optionalText('netdiskHint'),
      windows: optionalUrl('windows'),
      linux: optionalUrl('linux'),
      macos: optionalUrl('macos'),
      play: optionalUrl('play'),
    );
  }

  final String github;

  /// Android 通用 (universal) 安装包链接。
  final String? androidApk;

  /// Android arm64-v8a 专属精简安装包链接（优先于 [androidApk]）。
  final String? androidArm64V8aApk;

  /// Android armeabi-v7a 专属精简安装包链接（优先于 [androidApk]）。
  final String? androidArmeabiV7aApk;

  /// Android x86_64 专属精简安装包链接（优先于 [androidApk]）。
  final String? androidX8664Apk;

  /// 国内网盘分享链接（仅外链打开，不进 APK 下载白名单）。
  final String? androidNetdisk;

  /// 提取码等说明（可空）。
  final String? netdiskHint;
  final String? windows;
  final String? linux;
  final String? macos;
  final String? play;
}
