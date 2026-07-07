import 'dart:io';
import 'package:http/http.dart' as http;

/// 脚本：下载 Noto Sans SC (思源黑体) 字体文件并放置到 assets/fonts/
/// 该字体包含了简体中文常用汉字及英文数字。
void main() async {
  final fontDir = Directory('assets/fonts');
  if (!fontDir.existsSync()) {
    fontDir.createSync(recursive: true);
  }

  // 使用 Google Fonts 的直接下载链接 (TTF 格式)
  final Map<String, String> fonts = {
    'NotoSansSC-Regular.ttf': 'https://github.com/google/fonts/raw/main/ofl/notosanssc/NotoSansSC%5Bwght%5D.ttf',
    'NotoSansSC-Bold.ttf': 'https://github.com/google/fonts/raw/main/ofl/notosanssc/NotoSansSC%5Bwght%5D.ttf', // 暂时使用同一文件，或寻找特定 Bold
  };

  print('--- 开始下载思源黑体 (Noto Sans SC) ---');
  print('注意：思源黑体文件较大，请耐心等待...');

  for (var entry in fonts.entries) {
    final file = File('${fontDir.path}/${entry.key}');
    if (file.existsSync()) {
      print('${entry.key} 已存在，跳过。');
      continue;
    }

    print('正在从 ${entry.value} 下载 ${entry.key}...');
    try {
      final response = await http.get(Uri.parse(entry.value));
      if (response.statusCode == 200) {
        await file.writeAsBytes(response.bodyBytes);
        print('成功保存: ${entry.key}');
      } else {
        print('下载失败 (${response.statusCode}): ${entry.key}');
      }
    } catch (e) {
      print('下载出错: $e');
    }
  }

  print('\n--- 任务完成 ---');
  print('如果下载失败，请手动访问 https://fonts.google.com/specimen/Noto+Sans+SC 下载字体并解压到 assets/fonts/');
}
