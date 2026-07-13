import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:s1_app/providers/backup_provider.dart';
import 'package:s1_app/providers/settings_provider.dart';
import 'package:s1_app/providers/talker_provider.dart';
import 'package:s1_app/theme/app_theme.dart';
import 'package:s1_app/services/app_database.dart';
import 'package:s1_app/services/app_local_data.dart';
import 'package:s1_app/services/backup/s1_backup_codec.dart';
import 'package:s1_app/services/backup/s1_backup_service.dart';

void main() {
  group('backup provider functions', () {
    late AppDatabase db;
    late AppLocalData local;
    late _RecordingBackupService recordingService;

    setUp(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      db = AppDatabase.forTesting(NativeDatabase.memory());
      local = AppLocalData(db);
      await local.load();
      recordingService = _RecordingBackupService(local);
    });

    tearDown(() async {
      await db.close();
    });

    testWidgets('importS1Backup returns null when pick is cancelled',
        (tester) async {
      S1BackupImportResult? result;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localDataProvider.overrideWithValue(local),
            s1BackupServiceProvider.overrideWithValue(recordingService),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme('purple'),
            home: _ImportProbe(
              onDone: (value) => result = value,
            ),
          ),
        ),
      );

      await tester.tap(find.text('import'));
      await tester.pumpAndSettle();

      expect(result, isNull);
      expect(recordingService.importCalled, isFalse);
    });

    testWidgets('exportS1Backup invokes service export', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localDataProvider.overrideWithValue(local),
            s1BackupServiceProvider.overrideWithValue(recordingService),
            packageInfoProvider.overrideWith(
              (_) async => PackageInfo(
                appName: 'S1',
                packageName: 'com.example.s1',
                version: '1.0.0',
                buildNumber: '1',
              ),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme('purple'),
            home: const _ExportProbe(),
          ),
        ),
      );

      await tester.tap(find.text('export'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(recordingService.exportCalled, isTrue);
    });
  });
}

class _ImportProbe extends ConsumerWidget {
  const _ImportProbe({required this.onDone});

  final void Function(S1BackupImportResult?) onDone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: FilledButton(
        onPressed: () async => onDone(await importS1Backup(ref)),
        child: const Text('import'),
      ),
    );
  }
}

class _ExportProbe extends ConsumerWidget {
  const _ExportProbe();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: FilledButton(
        onPressed: () async {
          try {
            await exportS1Backup(ref);
          } on Object {
            // Platform share/pick may fail in widget tests.
          }
        },
        child: const Text('export'),
      ),
    );
  }
}

class _RecordingBackupService extends S1BackupService {
  _RecordingBackupService(super.local);

  bool exportCalled = false;
  bool importCalled = false;

  @override
  Future<S1BackupExportResult> exportL1({
    required String? uid,
    required PackageInfo packageInfo,
    String platform = 'unknown',
  }) async {
    exportCalled = true;
    final payload = S1BackupPayload(
      manifest: {
        'format': s1BackupFormatId,
        'format_version': s1BackupFormatVersion,
        'exported_at': '2026-07-13T00:00:00Z',
        'contents': <String>[],
      },
    );
    return S1BackupExportResult(
      bytes: Uint8List.fromList(const [1, 2, 3]),
      fileName: 'test.s1backup.zip',
      payload: payload,
    );
  }

  @override
  Future<S1BackupImportResult> importL1(List<int> bytes) async {
    importCalled = true;
    return S1BackupImportResult(
      readingHistoryUpserts: 0,
      pollVoteUpserts: 0,
      blacklistUpserts: 0,
      settingsApplied: 0,
    );
  }
}
