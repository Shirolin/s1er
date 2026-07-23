import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s1er/models/edit_post_form_info.dart';
import 'package:s1er/models/edit_post_submit_result.dart';
import 'package:s1er/models/forum_attachment_upload_info.dart';
import 'package:s1er/providers/auth_provider.dart';
import 'package:s1er/providers/compose_provider.dart';
import 'package:s1er/providers/settings_provider.dart';
import 'package:s1er/screens/compose_screen.dart';
import 'package:s1er/services/app_database.dart';
import 'package:s1er/services/app_local_data.dart';
import 'package:s1er/theme/app_theme.dart';
import 'package:s1er/utils/compose_message_draft.dart';
import 'package:s1er/utils/edit_post_draft.dart';
import 'package:s1er/utils/new_thread_draft.dart';
import 'package:s1er/widgets/s1_draft_leave_dialog.dart';

import '../helpers/test_local_data.dart';

void main() {
  late AppDatabase db;
  late AppLocalData local;

  setUp(() async {
    final opened = await openTestLocalData();
    db = opened.$1;
    local = opened.$2;
  });

  tearDown(() async => db.close());

  testWidgets(
    'edit reply must not pollute reply compose_message_drafts',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localDataProvider.overrideWithValue(local),
            authStateProvider.overrideWith(_LoggedInAuthNotifier.new),
            composeControllerProvider.overrideWith(
              (ref) => _EditComposeController(ref),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme('purple'),
            home: const ComposeScreen(
              tid: '100',
              fid: '4',
              editPid: '200',
              editIsFirst: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).last, '编辑正文不应进回复草稿');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // 模拟离开编辑页（dispose）
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localDataProvider.overrideWithValue(local),
            authStateProvider.overrideWith(_LoggedInAuthNotifier.new),
            composeControllerProvider.overrideWith(
              (ref) => _EditComposeController(ref),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme('purple'),
            home: const SizedBox.shrink(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final replyDrafts = ComposeMessageDraft.parseStore(
        local.settings.get<Object>(ComposeMessageDraft.settingsKey),
      );
      expect(
        ComposeMessageDraft.readMessage(replyDrafts, '100'),
        isNull,
        reason: '编辑不得写入 compose_message_drafts[{tid}]',
      );

      final editDrafts = EditPostDraftStore.parse(
        local.settings.get<Object>(EditPostDraftStore.settingsKey),
      );
      expect(editDrafts['200']?['message'], '编辑正文不应进回复草稿');

      // 打开新增回复：不得恢复编辑正文
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localDataProvider.overrideWithValue(local),
            authStateProvider.overrideWith(_LoggedInAuthNotifier.new),
            composeControllerProvider.overrideWith(
              (ref) => _EditComposeController(ref),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme('purple'),
            home: const ComposeScreen(
              tid: '100',
              fid: '4',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('已恢复草稿'), findsNothing);
      final replyField = tester.widget<TextField>(find.byType(TextField).last);
      expect(replyField.controller!.text, isNot('编辑正文不应进回复草稿'));
      expect(replyField.controller!.text.trim(), isEmpty);
    },
  );

  testWidgets('reply leave discard clears compose_message_drafts',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localDataProvider.overrideWithValue(local),
          authStateProvider.overrideWith(_LoggedInAuthNotifier.new),
          composeControllerProvider.overrideWith(
            (ref) => _EditComposeController(ref),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme('purple'),
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: Center(
                  child: TextButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const ComposeScreen(
                            tid: '100',
                            fid: '4',
                          ),
                        ),
                      );
                    },
                    child: const Text('open-compose'),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
    await tester.tap(find.text('open-compose'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).last, '将被放弃的回复');
    await tester.pump(const Duration(milliseconds: 500));

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.text('离开回复？'), findsOneWidget);
    await tester.tap(find.text('放弃草稿'));
    await tester.pumpAndSettle();

    final drafts = ComposeMessageDraft.parseStore(
      local.settings.get<Object>(ComposeMessageDraft.settingsKey),
    );
    expect(ComposeMessageDraft.readMessage(drafts, '100'), isNull);
  });

  testWidgets('reply leave keep persists compose_message_drafts',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localDataProvider.overrideWithValue(local),
          authStateProvider.overrideWith(_LoggedInAuthNotifier.new),
          composeControllerProvider.overrideWith(
            (ref) => _EditComposeController(ref),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme('purple'),
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: Center(
                  child: TextButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const ComposeScreen(
                            tid: '100',
                            fid: '4',
                          ),
                        ),
                      );
                    },
                    child: const Text('open-compose'),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
    await tester.tap(find.text('open-compose'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).last, '保留的回复草稿');
    await tester.pump(const Duration(milliseconds: 500));

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.text('离开回复？'), findsOneWidget);
    await tester.tap(find.text('保留并离开'));
    await tester.pumpAndSettle();

    final drafts = ComposeMessageDraft.parseStore(
      local.settings.get<Object>(ComposeMessageDraft.settingsKey),
    );
    expect(ComposeMessageDraft.readMessage(drafts, '100'), '保留的回复草稿');
  });

  test('new thread empty upsert removes entry', () {
    final drafts = NewThreadDraftStore.upsert(
      NewThreadDraftStore.upsert(
        {},
        '4',
        subject: 't',
        message: 'm',
      ),
      '4',
      subject: '',
      message: '',
    );
    expect(NewThreadDraftStore.toStoreValue(drafts), isNull);
  });

  testWidgets('showS1DraftLeaveDialog returns choices', (tester) async {
    late S1DraftLeaveChoice choice;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme('purple'),
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: TextButton(
                onPressed: () async {
                  choice = await showS1DraftLeaveDialog(
                    context,
                    title: '离开回复？',
                    content: '说明',
                  );
                },
                child: const Text('open'),
              ),
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('保留并离开'));
    await tester.pumpAndSettle();
    expect(choice, S1DraftLeaveChoice.keepAndLeave);
  });
}

class _EditComposeController extends ComposeController {
  _EditComposeController(super.ref);

  @override
  Future<ForumAttachmentUploadInfo?> prefetchAttachmentUploadInfo({
    required String fid,
    String? tid,
    ForumAttachmentUploadInfo? seed,
  }) async {
    return null;
  }

  @override
  Future<EditPostFormInfo> fetchEditPostForm({
    required String fid,
    required String tid,
    required String pid,
    required bool isFirst,
  }) async {
    return const EditPostFormInfo(
      message: '服务器原文',
      formhash: 'fixture',
    );
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
    return const EditPostSubmitResult.success(message: '编辑成功');
  }
}

class _LoggedInAuthNotifier extends AuthNotifier {
  @override
  AuthState build() => AuthState(isLoggedIn: true);
}
