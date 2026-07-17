import 'package:flutter_test/flutter_test.dart';
import 'package:s1er/services/api_service.dart';

void main() {
  const form = '''
<root><![CDATA[
<form id="reportform">
  <input type="hidden" name="formhash" value="abc123" />
  <input type="hidden" name="rid" value="99" />
  <input type="hidden" name="rtype" value="post" />
</form>
]]></root>''';

  test('parses report hidden fields and canonical referer', () {
    final result = ApiService.parseReportFormResponse(
      form,
      tid: '12',
      page: 3,
    );

    expect(result.hasError, isFalse);
    expect(result.reasons, [
      '广告垃圾',
      '违规内容',
      '恶意灌水',
      '重复发帖',
      '其他',
    ]);
    expect(result.fields['formhash'], 'abc123');
    expect(result.fields['rid'], '99');
    expect(result.fields['referer'], contains('tid=12'));
    expect(result.fields['referer'], contains('page=3'));
  });

  test('parses report login and business errors', () {
    expect(
      ApiService.parseReportFormResponse(
        '<div id="loginform_x"><input name="login" /></div>',
        tid: '1',
      ).error,
      '请先登录',
    );
    expect(
      ApiService.parseReportFormResponse(
        '<dt id="messagetext"><p>没有权限举报</p></dt>',
        tid: '1',
      ).error,
      '没有权限举报',
    );
  });

  test('recognizes report submit success and errors', () {
    expect(ApiService.parseReportSubmitResponse('举报成功'), isNull);
    expect(
      ApiService.parseReportSubmitResponse("errorhandle_report('已举报', '')"),
      '已举报',
    );
    expect(ApiService.parseReportSubmitResponse(''), contains('无响应'));
  });
}
