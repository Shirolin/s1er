class Emoticon { // e.g. "assets/emoticons/001.png"

  Emoticon({required this.code, required this.assetPath});
  final String code; // e.g. "[f:001]"
  final String assetPath;
}

class EmoticonMap {
  static final Map<String, String> _map = {};

  static void initialize() {
    // Will be populated from bundled assets
    for (int i = 1; i <= 100; i++) {
      final code = '[f:${i.toString().padLeft(3, '0')}]';
      final path = 'assets/emoticons/${i.toString().padLeft(3, '0')}.png';
      _map[code] = path;
    }
  }

  static String? getAssetPath(String code) => _map[code];
  static Map<String, String> get all => Map.unmodifiable(_map);
}
