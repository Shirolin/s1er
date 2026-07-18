import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_provider.dart';
import '../providers/blacklist_provider.dart';
import '../providers/reading_history_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/talker_provider.dart';
import '../services/backup/s1_backup_io.dart';
import '../services/backup/s1_backup_service.dart';

export '../services/backup/s1_backup_codec.dart' show S1BackupException;

final s1BackupServiceProvider = Provider<S1BackupService>((ref) {
  return S1BackupService(ref.watch(localDataProvider));
});

String _backupPlatformLabel() {
  if (kIsWeb) return 'web';
  return defaultTargetPlatform.name;
}

Future<S1BackupExportResult> exportS1Backup(WidgetRef ref) async {
  await ref.read(localDataProvider).flushPendingWrites();
  final packageInfo = await ref.read(packageInfoProvider.future);
  final uid = ref.read(authStateProvider).user?.uid;
  final result = await ref.read(s1BackupServiceProvider).exportL1(
        uid: uid,
        packageInfo: packageInfo,
        platform: _backupPlatformLabel(),
      );
  await S1BackupIo.shareOrDownload(
    bytes: result.bytes,
    fileName: result.fileName,
  );
  return result;
}

Future<S1BackupImportResult?> importS1Backup(WidgetRef ref) async {
  final bytes = await S1BackupIo.pickBackupBytes();
  if (bytes == null) return null;
  final result = await ref.read(s1BackupServiceProvider).importL1(bytes);
  ref.invalidate(settingsProvider);
  ref.invalidate(readingHistoryProvider);
  ref.invalidate(blacklistProvider);
  await ref.read(settingsProvider.notifier).syncAppIconWithNative();
  return result;
}
