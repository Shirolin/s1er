import 'package:flutter_test/flutter_test.dart';
import 'package:s1er/utils/new_thread_form_parser.dart';

void main() {
  group('parseNewThreadFormHtml', () {
    test('parses typeid options and typerequired from S1-style HTML', () {
      const html = '''
<script type="text/javascript">
var typerequired = parseInt('1');
</script>
<form>
  <select name="typeid" id="typeid">
    <option value="0">选择主题分类</option>
    <option value="47">其他</option>
    <option value="48">硬件</option>
    <option value="49" selected="selected">软件</option>
    <option value="50">外设</option>
  </select>
</form>
''';

      final form = parseNewThreadFormHtml(html);

      expect(form.typeRequired, isTrue);
      expect(form.threadTypes, {
        '47': '其他',
        '48': '硬件',
        '49': '软件',
        '50': '外设',
      });
    });

    test('unwraps ajax CDATA wrapper', () {
      const wrapped = '''
<?xml version="1.0" encoding="utf-8"?>
<root><![CDATA[
<select id="typeid"><option value="1">讨论</option></select>
<script>var typerequired = parseInt('0');</script>
]]></root>
''';

      final form = parseNewThreadFormHtml(wrapped);

      expect(form.typeRequired, isFalse);
      expect(form.threadTypes, {'1': '讨论'});
    });

    test('returns empty map for missing typeid', () {
      final form = parseNewThreadFormHtml('<form></form>');
      expect(form.threadTypes, isEmpty);
      expect(form.typeRequired, isNull);
    });
  });

  group('isPlaceholderThreadTypeOption', () {
    test('detects placeholder value 0', () {
      expect(isPlaceholderThreadTypeOption('0', '选择主题分类'), isTrue);
      expect(isPlaceholderThreadTypeOption('0', '其他'), isFalse);
      expect(isPlaceholderThreadTypeOption('47', '其他'), isFalse);
    });
  });
}
