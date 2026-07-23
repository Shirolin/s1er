import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import '../../models/image_load_policy.dart';

/// Highest `format_version` this client can import.
const int s1BackupFormatVersion = 1;

const String s1BackupFormatId = 's1-backup';

class S1BackupException implements Exception {
  S1BackupException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Decoded L1 payload (in-memory). Lists are JSON-compatible maps.
class S1BackupPayload {
  S1BackupPayload({
    required this.manifest,
    this.settings,
    this.readingHistory = const [],
    this.blacklist = const [],
    this.pollVotes = const [],
  });

  final Map<String, dynamic> manifest;
  final Map<String, dynamic>? settings;
  final List<Map<String, dynamic>> readingHistory;
  final List<Map<String, dynamic>> blacklist;
  final List<Map<String, dynamic>> pollVotes;

  List<String> get contents {
    final raw = manifest['contents'];
    if (raw is! List) return const [];
    return raw.map((e) => e.toString()).toList();
  }
}

/// Encode / decode `*.s1backup.zip` L1 archives (no Flutter / Drift deps).
class S1BackupCodec {
  static const _utf8 = Utf8Encoder();
  static const _utf8Decoder = Utf8Decoder();

  /// Compressed ZIP size cap (import).
  static const int maxCompressedBytes = 16 * 1024 * 1024;

  /// Total uncompressed payload cap across all entries.
  static const int maxUncompressedBytes = 32 * 1024 * 1024;

  /// Max archive entries (manifest + L1 JSON files).
  static const int maxEntryCount = 32;

  /// Max single uncompressed file size.
  static const int maxSingleFileBytes = 8 * 1024 * 1024;

  static Uint8List encode(S1BackupPayload payload) {
    final archive = Archive();
    void addJson(String name, Object value) {
      final bytes =
          _utf8.convert(const JsonEncoder.withIndent('  ').convert(value));
      archive.addFile(ArchiveFile(name, bytes.length, bytes));
    }

    addJson('manifest.json', payload.manifest);
    if (payload.settings != null) {
      addJson('settings.json', payload.settings!);
    }
    if (payload.contents.contains('reading_history') ||
        payload.readingHistory.isNotEmpty) {
      addJson('reading_history.json', payload.readingHistory);
    }
    if (payload.contents.contains('blacklist') ||
        payload.blacklist.isNotEmpty) {
      addJson('blacklist.json', payload.blacklist);
    }
    if (payload.contents.contains('poll_votes') ||
        payload.pollVotes.isNotEmpty) {
      addJson('poll_votes.json', payload.pollVotes);
    }

    return ZipEncoder().encodeBytes(archive);
  }

  static S1BackupPayload decode(Uint8List bytes) {
    if (bytes.length > maxCompressedBytes) {
      throw S1BackupException(
        '备份文件过大（超过 ${maxCompressedBytes ~/ (1024 * 1024)} MB）',
      );
    }

    Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes);
    } catch (e) {
      throw S1BackupException('无法解析备份 ZIP: $e');
    }

    _assertArchiveLimits(archive);

    Map<String, dynamic>? readJsonObject(String name) {
      final file = archive.findFile(name);
      if (file == null) return null;
      final content = _utf8Decoder.convert(file.content as List<int>);
      final decoded = jsonDecode(content);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
      throw S1BackupException('$name 必须是 JSON 对象');
    }

    List<Map<String, dynamic>> readJsonArray(String name) {
      final file = archive.findFile(name);
      if (file == null) return const [];
      final content = _utf8Decoder.convert(file.content as List<int>);
      final decoded = jsonDecode(content);
      if (decoded is! List) {
        throw S1BackupException('$name 必须是 JSON 数组');
      }
      return decoded.map((e) {
        if (e is Map<String, dynamic>) return e;
        if (e is Map) return Map<String, dynamic>.from(e);
        throw S1BackupException('$name 含有非法元素');
      }).toList();
    }

    final manifest = readJsonObject('manifest.json');
    if (manifest == null) {
      throw S1BackupException('缺少 manifest.json');
    }

    final format = manifest['format']?.toString();
    if (format != s1BackupFormatId) {
      throw S1BackupException('不是有效的 s1-backup（format=$format）');
    }

    final versionRaw = manifest['format_version'];
    final version = versionRaw is int
        ? versionRaw
        : int.tryParse(versionRaw?.toString() ?? '');
    if (version == null) {
      throw S1BackupException('manifest.format_version 无效');
    }
    if (version > s1BackupFormatVersion) {
      throw S1BackupException(
        '备份格式版本 $version 高于本应用支持的 $s1BackupFormatVersion',
      );
    }

    return S1BackupPayload(
      manifest: manifest,
      settings: readJsonObject('settings.json'),
      readingHistory: readJsonArray('reading_history.json'),
      blacklist: readJsonArray('blacklist.json'),
      pollVotes: readJsonArray('poll_votes.json'),
    );
  }

  static void _assertArchiveLimits(Archive archive) {
    if (archive.length > maxEntryCount) {
      throw S1BackupException('备份包含过多文件（超过 $maxEntryCount 个）');
    }
    var total = 0;
    for (final file in archive) {
      final size = file.size;
      if (size > maxSingleFileBytes) {
        throw S1BackupException(
          '备份内文件过大（超过 ${maxSingleFileBytes ~/ (1024 * 1024)} MB）',
        );
      }
      total += size;
      if (total > maxUncompressedBytes) {
        throw S1BackupException(
          '备份解压后过大（超过 ${maxUncompressedBytes ~/ (1024 * 1024)} MB）',
        );
      }
    }
  }
}

/// Maps app camelCase settings ↔ backup snake_case keys.
class S1BackupSettingsMapper {
  static const Map<String, String> appToBackup = {
    'themeMode': 'theme_mode',
    'themeColor': 'theme_color',
    'appIcon': 'app_icon',
    'showImages': 'show_images',
    'imageLoadPolicy': 'image_load_policy',
    'avatarLoadPolicy': 'avatar_load_policy',
    'maxImagesPerPost': 'max_images_per_post',
    'imageCacheLimitMb': 'image_cache_limit_mb',
    'recordReadingHistory': 'record_reading_history',
    'hapticsEnabled': 'haptics_enabled',
    'threadListDensity': 'thread_list_density',
    'postListDensity': 'post_list_density',
    'fontSize': 'font_size',
    'collapsedForums': 'collapsed_forums',
    'shareImageFormat': 'share_image_format',
    'sharePixelRatio': 'share_pixel_ratio',
    'postSignatureEnabled': 'post_signature_enabled',
    'postSignatureShowDevice': 'post_signature_show_device',
    'postSignatureCustom': 'post_signature_custom',
  };

  static Map<String, dynamic> toBackup(Map<String, Object?> appSettings) {
    final out = <String, dynamic>{};
    for (final entry in appToBackup.entries) {
      if (!appSettings.containsKey(entry.key)) continue;
      final value = appSettings[entry.key];
      if (value == null) continue;
      if (value is Set) {
        out[entry.value] = value.toList();
      } else if (entry.key == 'imageLoadPolicy' && value is String) {
        out[entry.value] = ImageLoadPolicy.fromStored(value).backupKey;
      } else if (entry.key == 'avatarLoadPolicy' && value is String) {
        out[entry.value] = ImageLoadPolicy.fromStored(value).backupKey;
      } else {
        out[entry.value] = value;
      }
    }
    return out;
  }

  static Map<String, Object?> toApp(Map<String, dynamic> backupSettings) {
    final out = <String, Object?>{};
    final reverse = {
      for (final e in appToBackup.entries) e.value: e.key,
    };
    for (final entry in backupSettings.entries) {
      final appKey = reverse[entry.key];
      if (appKey == null) continue; // unknown field: ignore
      final value = entry.value;
      if (appKey == 'collapsedForums' && value is List) {
        out[appKey] = value.map((e) => e.toString()).toList();
      } else if (appKey == 'imageLoadPolicy' && value is String) {
        out[appKey] = ImageLoadPolicy.fromBackup(value).storageKey;
      } else if (appKey == 'avatarLoadPolicy' && value is String) {
        out[appKey] = ImageLoadPolicy.fromBackup(value).storageKey;
      } else {
        out[appKey] = value;
      }
    }
    return out;
  }
}
