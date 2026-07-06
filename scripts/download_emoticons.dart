// scripts/download_emoticons.dart
// Run with: dart run scripts/download_emoticons.dart
// Downloads S1 emoticons from kawaiidora/s1emoticon repo

import 'dart:io';
import 'dart:convert';

void main() async {
  final dir = Directory('assets/emoticons');
  if (!dir.existsSync()) {
    dir.createSync(recursive: true);
  }

  // Map of emoticon codes to filenames
  final emoticonMap = <String, String>{};

  for (int i = 1; i <= 100; i++) {
    final code = i.toString().padLeft(3, '0');
    final fileName = '$code.png';
    final url = 'https://raw.githubusercontent.com/kawaiidora/s1emoticon/main/emoticons/$fileName';

    print('Downloading $fileName...');

    try {
      final client = HttpClient();
      final request = await client.getUrl(Uri.parse(url));
      final response = await request.close();
      final file = File('${dir.path}/$fileName');
      await response.pipe(file.openWrite());

      emoticonMap['[f:$code]'] = 'assets/emoticons/$fileName';
    } catch (e) {
      print('Failed to download $fileName: $e');
    }
  }

  // Save the mapping
  final mapFile = File('assets/emoticons/emoticon_map.json');
  await mapFile.writeAsString(jsonEncode(emoticonMap));

  print('Done! Downloaded ${emoticonMap.length} emoticons.');
}
