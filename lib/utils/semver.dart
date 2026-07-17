/// 轻量 semver 比较（MAJOR.MINOR.PATCH；缺段补 0；忽略 `+build` / 预发布后缀）。
class Semver {
  Semver._(this.major, this.minor, this.patch);

  final int major;
  final int minor;
  final int patch;

  /// 解析失败返回 null。
  static Semver? tryParse(String raw) {
    final name = raw.trim().split('+').first.split('-').first.trim();
    if (name.isEmpty) return null;
    final parts = name.split('.');
    if (parts.length > 3) return null;
    final nums = <int>[];
    for (final part in parts) {
      final n = int.tryParse(part);
      if (n == null || n < 0) return null;
      nums.add(n);
    }
    while (nums.length < 3) {
      nums.add(0);
    }
    return Semver._(nums[0], nums[1], nums[2]);
  }

  /// `a < b` → 负；相等 → 0；`a > b` → 正。解析失败视为不可比（抛 [FormatException]）。
  static int compare(String a, String b) {
    final left = tryParse(a);
    final right = tryParse(b);
    if (left == null || right == null) {
      throw FormatException('Invalid semver: "$a" vs "$b"');
    }
    if (left.major != right.major) return left.major.compareTo(right.major);
    if (left.minor != right.minor) return left.minor.compareTo(right.minor);
    return left.patch.compareTo(right.patch);
  }

  static bool isLessThan(String a, String b) => compare(a, b) < 0;

  static bool isGreaterThan(String a, String b) => compare(a, b) > 0;
}
