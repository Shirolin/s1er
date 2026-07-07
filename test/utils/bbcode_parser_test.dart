import 'package:flutter_test/flutter_test.dart';
import 'package:s1_app/utils/bbcode_parser.dart';

void main() {
  group('BbcodeParser 换行处理测试', () {
    test('应该将连续的 <br/>\\n 合并，避免过多空行', () {
      const input = '第一行<br />\n<br />\n第二行';
      // _preClean 会先将 <br /> 转为 <br/>
      // 然后正则匹配 (<br/>\s*|[\n\r]\s*){3,} 
      // "第一行<br/>\n<br/>\n第二行" 这里的匹配项是 "<br/>\n<br/>\n"，长度符合折叠条件
      final output = BbcodeParser.parse(input);
      expect(output, contains('第一行<br/><br/>第二行'));
    });

    test('超过 3 个换行应该被折叠为 2 个', () {
      const input = 'A<br/><br/><br/><br/>B';
      final output = BbcodeParser.parse(input);
      expect(output, contains('A<br/><br/>B'));
    });

    test('2 个换行（一个空行）应该被保留', () {
      const input = 'A<br/><br/>B';
      final output = BbcodeParser.parse(input);
      expect(output, contains('A<br/><br/>B'));
    });
  });
}
