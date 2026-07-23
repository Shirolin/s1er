import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
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
import 'package:s1er/widgets/bbcode_renderer.dart';

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

  testWidgets('edit mode loads server content and title controls',
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
            editIsFirst: true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('编辑主题'), findsOneWidget);
    expect(find.text('主题标题'), findsOneWidget);
    expect(find.text('原标题'), findsOneWidget);
    expect(find.text('保存编辑'), findsOneWidget);
    expect(find.text('原始正文'), findsOneWidget);
  });

  testWidgets('edit reply shows thread subject like compose reply',
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
            subject: '实体版好价讨论',
            editPid: '200',
            editIsFirst: false,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('编辑回复'), findsOneWidget);
    expect(find.textContaining('主题 · 实体版好价讨论'), findsOneWidget);
  });

  testWidgets('edit first post does not stack read-only subject line',
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
            subject: '实体版好价讨论',
            editPid: '200',
            editIsFirst: true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('编辑主题'), findsOneWidget);
    expect(find.text('主题标题'), findsOneWidget);
    expect(find.textContaining('主题 · 实体版好价讨论'), findsNothing);
  });

  testWidgets('edit mode shows reply-style quote banner and hides signature',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localDataProvider.overrideWithValue(local),
          authStateProvider.overrideWith(_LoggedInAuthNotifier.new),
          composeControllerProvider.overrideWith(
            (ref) => _QuotedEditComposeController(ref),
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

    expect(find.text('编辑回复'), findsOneWidget);
    expect(find.text('pdd叠券能到260+'), findsOneWidget);
    // 与回复页一致：引用条纯文本，不是 QuoteBlock 渲染 BBCode。
    expect(find.text('引用 · 二十二颗牛油果'), findsOneWidget);
    // 紧凑屏默认折叠摘要，点开后再核对正文预览。
    await tester.tap(find.text('引用 · 二十二颗牛油果'));
    await tester.pumpAndSettle();
    expect(find.text('现在实体版有好价吗'), findsOneWidget);
    expect(find.byType(BbcodeRenderer), findsNothing);
    expect(find.textContaining('[quote]'), findsNothing);
    expect(find.textContaining('[/size]'), findsNothing);
    expect(find.textContaining('S1er 客户端'), findsNothing);
    expect(find.textContaining('[size=1]'), findsNothing);
    expect(find.byTooltip('移除引用'), findsOneWidget);
  });

  testWidgets('edit mode moves images to placeholders out of raw bbcode',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localDataProvider.overrideWithValue(local),
          authStateProvider.overrideWith(_LoggedInAuthNotifier.new),
          composeControllerProvider.overrideWith(
            (ref) => _ImageEditComposeController(ref),
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
    // CachedNetworkImage 会持续调度，避免 pumpAndSettle 挂死。
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.textContaining('看这张图'), findsOneWidget);
    expect(find.textContaining('⟦图1⟧'), findsOneWidget);
    expect(find.text('图片 1'), findsOneWidget);
    expect(find.byType(InputChip), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(InputChip),
        matching: find.byType(CachedNetworkImage),
      ),
      findsOneWidget,
    );
    expect(find.byTooltip('photo.webp'), findsOneWidget);
    expect(find.textContaining('[img]'), findsNothing);
    expect(find.textContaining('p.sda1.dev'), findsNothing);
  });

  testWidgets('edit mode shows attachimg fallback without raw bbcode',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localDataProvider.overrideWithValue(local),
          authStateProvider.overrideWith(_LoggedInAuthNotifier.new),
          composeControllerProvider.overrideWith(
            (ref) => _AttachEditComposeController(ref),
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
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.textContaining('附图说明'), findsOneWidget);
    expect(find.textContaining('⟦图1⟧'), findsOneWidget);
    expect(find.text('图片 1'), findsOneWidget);
    expect(find.byTooltip('论坛图片 · 99'), findsOneWidget);
    expect(
      find.textContaining('⟦图N⟧ 可挪动'),
      findsOneWidget,
    );
    expect(find.textContaining('[attachimg]'), findsNothing);
    expect(find.byIcon(Icons.image_not_supported_outlined), findsOneWidget);
  });

  testWidgets('edit mode expands placeholders in original layout on submit',
      (tester) async {
    late _CaptureLayoutEditComposeController controller;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localDataProvider.overrideWithValue(local),
          authStateProvider.overrideWith(_LoggedInAuthNotifier.new),
          composeControllerProvider.overrideWith((ref) {
            controller = _CaptureLayoutEditComposeController(ref);
            return controller;
          }),
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
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.textContaining('⟦图1⟧'), findsOneWidget);
    expect(find.textContaining('⟦图2⟧'), findsOneWidget);

    final field = find.byType(TextField).last;
    await tester.enterText(field, '先⟦图2⟧再⟦图1⟧');
    await tester.pump();
    await tester.tap(find.text('保存编辑'));
    await tester.pump();
    await tester.tap(find.text('确认编辑'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(
      controller.lastMessage,
      '先[img]https://a.test/2.png[/img]再[img]https://a.test/1.png[/img]',
    );
  });

  testWidgets('edit success pops back even when draft is dirty',
      (tester) async {
    EditPostSubmitResult? popped;
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
                  child: FilledButton(
                    onPressed: () async {
                      popped = await Navigator.of(context)
                          .push<EditPostSubmitResult>(
                        MaterialPageRoute(
                          builder: (_) => const ComposeScreen(
                            tid: '100',
                            fid: '4',
                            editPid: '200',
                            editIsFirst: false,
                          ),
                        ),
                      );
                    },
                    child: const Text('open-edit'),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('open-edit'));
    await tester.pumpAndSettle();

    expect(find.text('编辑回复'), findsOneWidget);
    await tester.enterText(find.byType(TextField).last, '改过的正文');
    await tester.pump();
    await tester.tap(find.text('保存编辑'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确认编辑'));
    await tester.pumpAndSettle();

    expect(find.text('open-edit'), findsOneWidget);
    expect(popped?.isSuccess, isTrue);
  });

  testWidgets('edit success pops via GoRouter when dirty', (tester) async {
    EditPostSubmitResult? popped;
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () async {
                  popped = await context.push<EditPostSubmitResult>(
                    '/thread/100/post/200/edit?fid=4&first=0',
                  );
                },
                child: const Text('open-edit'),
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/thread/:tid/post/:pid/edit',
          builder: (context, state) => ComposeScreen(
            tid: state.pathParameters['tid'],
            fid: state.uri.queryParameters['fid'],
            editPid: state.pathParameters['pid'],
            editIsFirst: state.uri.queryParameters['first'] == '1',
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localDataProvider.overrideWithValue(local),
          authStateProvider.overrideWith(_LoggedInAuthNotifier.new),
          composeControllerProvider.overrideWith(
            (ref) => _EditComposeController(ref),
          ),
        ],
        child: MaterialApp.router(
          theme: AppTheme.lightTheme('purple'),
          routerConfig: router,
        ),
      ),
    );

    await tester.tap(find.text('open-edit'));
    await tester.pumpAndSettle();

    expect(find.text('编辑回复'), findsOneWidget);
    await tester.enterText(find.byType(TextField).last, '改过的正文');
    await tester.pump();
    await tester.tap(find.text('保存编辑'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确认编辑'));
    await tester.pumpAndSettle();

    expect(find.text('open-edit'), findsOneWidget);
    expect(popped?.isSuccess, isTrue);
    expect(router.state.uri.path, '/');
  });
}

class _EditComposeController extends ComposeController {
  _EditComposeController(super.ref);

  @override
  Future<ForumAttachmentUploadInfo?> prefetchAttachmentUploadInfo({
    required String fid,
    String? tid,
    String? editPid,
    ForumAttachmentUploadInfo? seed,
  }) async =>
      null;

  @override
  Future<EditPostFormInfo> fetchEditPostForm({
    required String fid,
    required String tid,
    required String pid,
    required bool isFirst,
  }) async {
    return const EditPostFormInfo(
      subject: '原标题',
      message: '原始正文',
      formhash: 'fixture',
      isFirst: true,
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

class _QuotedEditComposeController extends ComposeController {
  _QuotedEditComposeController(super.ref);

  @override
  Future<ForumAttachmentUploadInfo?> prefetchAttachmentUploadInfo({
    required String fid,
    String? tid,
    String? editPid,
    ForumAttachmentUploadInfo? seed,
  }) async =>
      null;

  @override
  Future<EditPostFormInfo> fetchEditPostForm({
    required String fid,
    required String tid,
    required String pid,
    required bool isFirst,
  }) async {
    return const EditPostFormInfo(
      message:
          '[quote][size=2][url=forum.php?mod=redirect&goto=findpost&pid=1&ptid=100]'
          '二十二颗牛油果[/url] 发表于 07-19 14:32[/size]\n'
          '现在实体版有好价吗\n'
          '[/quote]\n'
          'pdd叠券能到260+\n\n'
          '[size=1][color=gray]——有点困 · 来自 Pixel 7a 上的 '
          '[url=https://github.com/Shirolin/s1er/releases/latest]S1er 客户端[/url]'
          '[/color][/size]',
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

class _ImageEditComposeController extends ComposeController {
  _ImageEditComposeController(super.ref);

  @override
  Future<ForumAttachmentUploadInfo?> prefetchAttachmentUploadInfo({
    required String fid,
    String? tid,
    String? editPid,
    ForumAttachmentUploadInfo? seed,
  }) async =>
      null;

  @override
  Future<EditPostFormInfo> fetchEditPostForm({
    required String fid,
    required String tid,
    required String pid,
    required bool isFirst,
  }) async {
    return const EditPostFormInfo(
      message: '看这张图[img]https://p.sda1.dev/33/abc/photo.webp[/img]',
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

class _AttachEditComposeController extends ComposeController {
  _AttachEditComposeController(super.ref);

  @override
  Future<ForumAttachmentUploadInfo?> prefetchAttachmentUploadInfo({
    required String fid,
    String? tid,
    String? editPid,
    ForumAttachmentUploadInfo? seed,
  }) async =>
      null;

  @override
  Future<EditPostFormInfo> fetchEditPostForm({
    required String fid,
    required String tid,
    required String pid,
    required bool isFirst,
  }) async {
    return const EditPostFormInfo(
      message: '附图说明[attachimg]99[/attachimg]',
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

class _CaptureLayoutEditComposeController extends ComposeController {
  _CaptureLayoutEditComposeController(super.ref);

  String? lastMessage;

  @override
  Future<ForumAttachmentUploadInfo?> prefetchAttachmentUploadInfo({
    required String fid,
    String? tid,
    String? editPid,
    ForumAttachmentUploadInfo? seed,
  }) async =>
      null;

  @override
  Future<EditPostFormInfo> fetchEditPostForm({
    required String fid,
    required String tid,
    required String pid,
    required bool isFirst,
  }) async {
    return const EditPostFormInfo(
      message:
          '前[img]https://a.test/1.png[/img]后[img]https://a.test/2.png[/img]',
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
    lastMessage = message;
    return const EditPostSubmitResult.success(message: '编辑成功');
  }
}

class _LoggedInAuthNotifier extends AuthNotifier {
  @override
  AuthState build() => AuthState(isLoggedIn: true);
}
