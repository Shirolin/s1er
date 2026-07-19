import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s1er/config/constants.dart';
import 'package:s1er/models/edit_post_form_info.dart';
import 'package:s1er/models/edit_post_submit_result.dart';
import 'package:s1er/models/new_thread_submit_result.dart';
import 'package:s1er/models/quote_info.dart';
import 'package:s1er/models/reply_submit_result.dart';
import 'package:s1er/providers/api_service_provider.dart';
import 'package:s1er/providers/compose_provider.dart';
import 'package:s1er/providers/settings_provider.dart';
import 'package:s1er/services/api_service.dart';
import 'package:s1er/providers/device_model_label_provider.dart';
import 'package:s1er/services/http_client.dart';

class _RecordingApiService extends ApiService {
  _RecordingApiService() : super(S1HttpClient.test(ProviderContainer(), Dio()));

  String? lastReplyMessage;
  String? lastNoticeAuthorMsg;
  String? lastThreadMessage;
  String? lastEditMessage;

  @override
  Future<ReplySubmitResult> sendReply({
    required String tid,
    required String fid,
    required String message,
    QuoteInfo? quoteInfo,
    String? noticeAuthorMsg,
  }) async {
    lastReplyMessage = message;
    lastNoticeAuthorMsg = noticeAuthorMsg;
    return ReplySubmitResult(pid: '1', tid: tid);
  }

  @override
  Future<NewThreadSubmitResult> submitNewThread({
    required String fid,
    required String subject,
    required String message,
    String? typeId,
  }) async {
    lastThreadMessage = message;
    return const NewThreadSubmitResult(tid: '9');
  }

  @override
  Future<EditPostSubmitResult> submitEditPost({
    required String fid,
    required String tid,
    required String pid,
    required bool isFirst,
    required String subject,
    required String message,
    String? typeId,
    String? readPerm,
    required EditPostFormInfo baseline,
  }) async {
    lastEditMessage = message;
    return const EditPostSubmitResult.success(message: '编辑成功');
  }
}

void main() {
  test('submitReply appends signature; notice keeps user body', () async {
    final api = _RecordingApiService();
    final container = ProviderContainer(
      overrides: [
        apiServiceProvider.overrideWithValue(api),
        settingsProvider.overrideWith(
          () => SettingsNotifier(
            initial: const AppSettings(
              postSignatureEnabled: true,
              postSignatureShowDevice: true,
              postSignatureCustom: '摸鱼',
            ),
          ),
        ),
        deviceModelLabelProvider.overrideWith((ref) async => 'Pixel 8'),
      ],
    );
    addTearDown(container.dispose);

    await container.read(composeControllerProvider).submitReply(
          tid: '100',
          fid: '4',
          message: '你好',
          quoteInfo: const QuoteInfo(
            noticeAuthor: 'a',
            noticeTrimStr: '[post]x[/post]',
          ),
        );

    expect(api.lastNoticeAuthorMsg, '你好');
    expect(
      api.lastReplyMessage,
      '你好\n\n'
      '[size=1][color=gray]——摸鱼 · 来自 Pixel 8 上的 '
      '[url=${S1Constants.downloadUrl}]S1er 客户端[/url][/color][/size]',
    );
  });

  test('submitNewThread appends signature when enabled', () async {
    final api = _RecordingApiService();
    final container = ProviderContainer(
      overrides: [
        apiServiceProvider.overrideWithValue(api),
        settingsProvider.overrideWith(
          () => SettingsNotifier(
            initial: const AppSettings(
              postSignatureEnabled: true,
              postSignatureShowDevice: false,
              postSignatureCustom: '',
            ),
          ),
        ),
        deviceModelLabelProvider.overrideWith((ref) async => 'ignored'),
      ],
    );
    addTearDown(container.dispose);

    await container.read(composeControllerProvider).submitNewThread(
          fid: '4',
          subject: '标题',
          message: '正文',
        );

    expect(
      api.lastThreadMessage,
      '正文\n\n'
      '[size=1][color=gray]——来自 '
      '[url=${S1Constants.downloadUrl}]S1er 客户端[/url][/color][/size]',
    );
  });

  test('disabled signature leaves message unchanged', () async {
    final api = _RecordingApiService();
    final container = ProviderContainer(
      overrides: [
        apiServiceProvider.overrideWithValue(api),
        settingsProvider.overrideWith(
          () => SettingsNotifier(
            initial: const AppSettings(postSignatureEnabled: false),
          ),
        ),
        deviceModelLabelProvider.overrideWith((ref) async => 'Pixel 8'),
      ],
    );
    addTearDown(container.dispose);

    await container.read(composeControllerProvider).submitReply(
          tid: '100',
          fid: '4',
          message: '纯正文',
        );

    expect(api.lastReplyMessage, '纯正文');
  });

  test('submitEditPost appends signature like reply', () async {
    final api = _RecordingApiService();
    final container = ProviderContainer(
      overrides: [
        apiServiceProvider.overrideWithValue(api),
        settingsProvider.overrideWith(
          () => SettingsNotifier(
            initial: const AppSettings(
              postSignatureEnabled: true,
              postSignatureShowDevice: true,
              postSignatureCustom: '',
            ),
          ),
        ),
        deviceModelLabelProvider.overrideWith((ref) async => 'Pixel 7a'),
      ],
    );
    addTearDown(container.dispose);

    await container.read(composeControllerProvider).submitEditPost(
          fid: '4',
          tid: '100',
          pid: '200',
          isFirst: false,
          subject: '',
          message: '[quote]q[/quote]\npdd叠券能到260+',
          baseline: const EditPostFormInfo(
            message: 'baseline',
            formhash: 'fh',
          ),
        );

    expect(
      api.lastEditMessage,
      '[quote]q[/quote]\npdd叠券能到260+\n\n'
      '[size=1][color=gray]——来自 Pixel 7a 上的 '
      '[url=${S1Constants.downloadUrl}]S1er 客户端[/url][/color][/size]',
    );
  });
}
