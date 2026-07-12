import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_selector/file_selector.dart';

import 'backup_download_stub.dart'
    if (dart.library.html) 'backup_download_web.dart';

/// Platform IO for L1 backup share / pick (no business logic).
class S1BackupIo {
  static Future<void> shareOrDownload({
    required Uint8List bytes,
    required String fileName,
  }) async {
    if (kIsWeb) {
      await downloadBackupWeb(bytes, fileName);
      return;
    }

    final dir = await getTemporaryDirectory();
    final path = p.join(dir.path, fileName);
    final staged = XFile.fromData(
      bytes,
      mimeType: 'application/zip',
      name: fileName,
    );
    await staged.saveTo(path);
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(path, mimeType: 'application/zip', name: fileName)],
        subject: fileName,
      ),
    );
  }

  static Future<Uint8List?> pickBackupBytes() async {
    const typeGroup = XTypeGroup(
      label: 'S1 Backup',
      extensions: <String>['zip'],
      mimeTypes: <String>['application/zip', 'application/x-zip-compressed'],
      uniformTypeIdentifiers: <String>['public.zip-archive'],
    );
    final file = await openFile(acceptedTypeGroups: <XTypeGroup>[typeGroup]);
    if (file == null) return null;
    return file.readAsBytes();
  }
}
