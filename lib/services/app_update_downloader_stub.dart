import 'package:dio/dio.dart';

import '../models/app_exceptions.dart';

/// 应用内 APK 下载结果。
class AppUpdateDownloadResult {
  const AppUpdateDownloadResult({
    required this.filePath,
    required this.sourceUrl,
  });

  final String filePath;
  final String sourceUrl;
}

/// Web / 无 IO：不支持应用内 APK 下载。
class AppUpdateDownloader {
  AppUpdateDownloader({
    Dio? dio,
    Future<dynamic> Function()? temporaryDirectory,
  });

  void cancel() {}

  Future<AppUpdateDownloadResult> downloadApk({
    required List<String> urls,
    required String versionLabel,
    void Function(double progress)? onProgress,
  }) async {
    throw const UpdateCheckException('当前平台不支持应用内下载');
  }
}
