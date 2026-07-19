import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s1er/models/edit_post_submit_result.dart';
import 'package:s1er/services/api_service.dart';
import 'package:s1er/services/http_client.dart';

void main() {
  const replyForm = '''
<form>
  <input type="hidden" name="formhash" value="fh" />
  <textarea id="e_textarea">原始 [b]BBCode[/b]</textarea>
</form>
''';
  const threadForm = '''
<form>
  <input type="hidden" name="formhash" value="fh" />
  <input type="hidden" name="special" value="0" />
  <input id="subject" value="原标题" />
  <select id="typeid"><option value="1" selected>其他</option></select>
  <select id="readperm"><option value="0" selected>不限</option><option value="10">10</option></select>
  <textarea id="e_textarea">原始正文</textarea>
</form>
''';

  test('parses reply editor without subject controls', () {
    final form = ApiService.parseEditPostFormResponse(
      replyForm,
      isFirst: false,
    );
    expect(form.canEdit, isTrue);
    expect(form.message, '原始 [b]BBCode[/b]');
    expect(form.subject, isEmpty);
    expect(form.formhash, 'fh');
  });

  test('parses first-post title, type and read permission', () {
    final form = ApiService.parseEditPostFormResponse(
      threadForm,
      isFirst: true,
    );
    expect(form.canEdit, isTrue);
    expect(form.subject, '原标题');
    expect(form.selectedTypeId, '1');
    expect(form.selectedReadPermission, '0');
  });

  test('parses touch/mobile editor (#needmessage / #needsubject)', () {
    const mobileForm = '''
<form id="postform">
  <input type="hidden" name="formhash" id="formhash" value="mobile-fh" />
  <input type="hidden" name="special" value="0" />
  <input type="text" id="needsubject" name="subject" value="触屏标题" />
  <select id="typeid" name="typeid">
    <option value="2" selected="selected">讨论</option>
  </select>
  <textarea class="pt" id="needmessage" name="message">触屏 [i]正文[/i]</textarea>
</form>
''';
    final form = ApiService.parseEditPostFormResponse(
      mobileForm,
      isFirst: true,
    );
    expect(form.canEdit, isTrue);
    expect(form.formhash, 'mobile-fh');
    expect(form.subject, '触屏标题');
    expect(form.message, '触屏 [i]正文[/i]');
    expect(form.selectedTypeId, '2');
  });

  test('extracts aimg urls from edit form html for preview', () {
    const html = '''
<form>
  <input type="hidden" name="formhash" value="fh" />
  <textarea id="e_textarea">看图[attachimg]2098060[/attachimg]</textarea>
  <a href="https://img.stage1st.com/forum/a.png"><img id="aimg_2098060"
    src="https://img.stage1st.com/forum/a.png.thumb.jpg" /></a>
</form>
''';
    final form = ApiService.parseEditPostFormResponse(html, isFirst: false);
    expect(form.canEdit, isTrue);
    expect(
      form.attachImageUrls['2098060'],
      'https://img.stage1st.com/forum/a.png',
    );
  });

  test('permission error never becomes an editable form', () {
    final form = ApiService.parseEditPostFormResponse(
      '<div id="messagetext"><p>没有权限编辑他人发表的帖子</p></div>',
      isFirst: false,
    );
    expect(form.canEdit, isFalse);
    expect(form.error, contains('没有权限'));
  });

  test('surfaces touch jump_c tip instead of missing-field error', () {
    final form = ApiService.parseEditPostFormResponse(
      '<div class="jump_c"><p>抱歉，指定的主题不存在或已被删除或正在被审核</p></div>',
      isFirst: false,
    );
    expect(form.canEdit, isFalse);
    expect(form.error, contains('指定的主题不存在'));
  });

  test('content conflict performs no POST', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final adapter = _CaptureAdapter([
      threadForm.replaceFirst('原始正文', '服务器新正文'),
    ]);
    final api = ApiService(
      S1HttpClient.test(container, Dio()..httpClientAdapter = adapter),
    );
    final baseline = ApiService.parseEditPostFormResponse(
      threadForm,
      isFirst: true,
    );

    final result = await api.submitEditPost(
      fid: '4',
      tid: '100',
      pid: '200',
      isFirst: true,
      subject: '原标题',
      message: '我的修改',
      typeId: '1',
      readPerm: '0',
      baseline: baseline,
    );

    expect(result.isConflict, isTrue);
    expect(adapter.requests, hasLength(1));
    expect(adapter.requests.single.method, 'GET');
  });

  test('success posts the exact edit contract once', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final adapter = _CaptureAdapter([threadForm, 'succeedhandle_postform()']);
    final api = ApiService(
      S1HttpClient.test(container, Dio()..httpClientAdapter = adapter),
    );
    final baseline = ApiService.parseEditPostFormResponse(
      threadForm,
      isFirst: true,
    );

    final result = await api.submitEditPost(
      fid: '4',
      tid: '100',
      pid: '200',
      isFirst: true,
      subject: '新标题',
      message: '新正文',
      typeId: '1',
      readPerm: '0',
      baseline: baseline,
    );

    expect(result.disposition, EditPostDisposition.success);
    expect(adapter.requests, hasLength(2));
    final request = adapter.requests[1];
    expect(request.method, 'POST');
    expect(request.path, contains('action=edit'));
    expect(request.path, contains('editsubmit=yes'));
    final data = request.data as Map;
    expect(data['fid'], '4');
    expect(data['tid'], '100');
    expect(data['pid'], '200');
    expect(data['formhash'], 'fh');
    expect(data['subject'], '新标题');
    expect(data['message'], '新正文');
    expect(data['typeid'], '1');
    expect(data['readperm'], '0');
    expect(data.containsKey('delete'), isFalse);
  });

  test('unknown POST response is uncertain and not retried', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final adapter = _CaptureAdapter([threadForm, 'unknown response']);
    final api = ApiService(
      S1HttpClient.test(container, Dio()..httpClientAdapter = adapter),
    );
    final baseline = ApiService.parseEditPostFormResponse(
      threadForm,
      isFirst: true,
    );
    final result = await api.submitEditPost(
      fid: '4',
      tid: '100',
      pid: '200',
      isFirst: true,
      subject: '新标题',
      message: '新正文',
      typeId: '1',
      readPerm: '0',
      baseline: baseline,
    );
    expect(result.isUncertain, isTrue);
    expect(adapter.requests, hasLength(2));
  });
}

class _CaptureAdapter implements HttpClientAdapter {
  _CaptureAdapter(this.responses);

  final List<String> responses;
  final requests = <RequestOptions>[];

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      responses[requests.length - 1],
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.textPlainContentType],
      },
    );
  }
}
