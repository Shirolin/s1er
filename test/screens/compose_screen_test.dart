import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:s1er/models/post.dart';
import 'package:s1er/models/quote_info.dart';
import 'package:s1er/models/reply_submit_result.dart';
import 'package:s1er/models/new_thread_form_info.dart';
import 'package:s1er/providers/auth_provider.dart';
import 'package:s1er/providers/compose_provider.dart';
import 'package:s1er/providers/forum_name_provider.dart';
import 'package:s1er/providers/settings_provider.dart';
import 'package:s1er/screens/compose_screen.dart';
import 'package:s1er/services/app_database.dart';
import 'package:s1er/services/app_local_data.dart';
import 'package:s1er/providers/device_model_label_provider.dart';
import 'package:s1er/theme/app_theme.dart';
import 'package:s1er/utils/compose_draft_store.dart';
import 'package:s1er/utils/compose_message_draft.dart';
import 'package:s1er/utils/window_size.dart';
import 'package:s1er/widgets/quote_block.dart';

import '../helpers/test_local_data.dart';

void main() {
  late AppDatabase db;
  late AppLocalData local;

  setUp(() async {
    final opened = await openTestLocalData();
    db = opened.$1;
    local = opened.$2;
  });

  tearDown(() async {
    await db.close();
  });

  List<Override> buildOverrides({
    required AuthNotifier Function() auth,
    ComposeController Function(Ref ref)? compose,
  }) {
    return [
      localDataProvider.overrideWithValue(local),
      authStateProvider.overrideWith(auth),
      composeControllerProvider.overrideWith(
        compose ?? (ref) => _StubComposeController(ref),
      ),
      deviceModelLabelProvider.overrideWith((ref) async => 'TestDevice'),
    ];
  }

  final samplePost = Post(
    pid: '42',
    message: 'quoted content here',
    author: 'alice',
    authorId: '7',
    dateline: 1704067200,
    floor: 3,
  );

  testWidgets('ComposeScreen shows quote preview when draft is provided',
      (tester) async {
    final draftId = ComposeDraftStore.put(samplePost, displayFloor: 5);

    await tester.pumpWidget(
      ProviderScope(
        overrides: buildOverrides(auth: _LoggedInAuthNotifier.new),
        child: MaterialApp(
          theme: AppTheme.lightTheme('purple'),
          home: ComposeScreen(
            tid: '100',
            fid: '4',
            draftId: draftId,
            reppost: '42',
            subject: '示例主题标题',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('回复 #5 楼'), findsOneWidget);
    expect(find.textContaining('引用 #5 楼'), findsOneWidget);
    expect(find.textContaining('alice'), findsWidgets);
    expect(find.textContaining('quoted content'), findsOneWidget);
    expect(find.textContaining('主题 · 示例主题标题'), findsOneWidget);
    expect(find.text('发送'), findsOneWidget);
    expect(find.text('图片'), findsOneWidget);
    expect(find.text('表情'), findsOneWidget);
    expect(find.byTooltip('预览'), findsOneWidget);
    expect(find.byIcon(Icons.image_outlined), findsOneWidget);
    expect(find.byType(FilledButton), findsOneWidget);
  });

  testWidgets('new thread mode renders title and required category',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...buildOverrides(auth: _LoggedInAuthNotifier.new),
          forumNameProvider('4').overrideWith((ref) => '游戏论坛'),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme('purple'),
          home: const ComposeScreen(fid: '4', newThread: true),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('发新主题'), findsOneWidget);
    expect(find.text('游戏论坛'), findsOneWidget);
    expect(find.text('主题标题'), findsOneWidget);
    expect(find.text('主题分类'), findsOneWidget);
    expect(find.byType(DropdownMenu<String>), findsOneWidget);
    expect(find.text('发送'), findsOneWidget);
  });

  testWidgets('ComposeScreen shows simple quote banner for reppost only',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: buildOverrides(auth: _LoggedInAuthNotifier.new),
        child: MaterialApp(
          theme: AppTheme.lightTheme('purple'),
          home: const ComposeScreen(
            tid: '100',
            fid: '4',
            reppost: '42',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('回复楼层'), findsOneWidget);
    expect(find.text('引用楼层'), findsOneWidget);
    expect(find.byTooltip('移除引用'), findsOneWidget);
  });

  testWidgets('ComposeScreen restores persisted message draft', (tester) async {
    local.settings.put(
      ComposeMessageDraft.settingsKey,
      ComposeMessageDraft.toStoreValue(
        ComposeMessageDraft.upsert({}, '100', '草稿正文内容'),
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: buildOverrides(auth: _LoggedInAuthNotifier.new),
        child: MaterialApp(
          theme: AppTheme.lightTheme('purple'),
          home: const ComposeScreen(tid: '100', fid: '4'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller!.text, '草稿正文内容');
    expect(find.text('已恢复草稿'), findsOneWidget);
  });

  testWidgets('ComposeScreen preview shows QuoteBlock when quoting',
      (tester) async {
    final draftId = ComposeDraftStore.put(samplePost, displayFloor: 5);

    await tester.pumpWidget(
      ProviderScope(
        overrides: buildOverrides(auth: _LoggedInAuthNotifier.new),
        child: MaterialApp(
          theme: AppTheme.lightTheme('purple'),
          home: ComposeScreen(
            tid: '100',
            fid: '4',
            draftId: draftId,
            reppost: '42',
            subject: '示例主题标题',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '我的回复正文');
    await tester.pump();
    await tester.tap(find.byTooltip('预览'));
    await tester.pumpAndSettle();

    expect(find.text('预览'), findsWidgets);
    // 编辑页主题条 + 预览卡上方上下文，各一条。
    expect(find.text('主题 · 示例主题标题'), findsNWidgets(2));
    expect(find.text('tester'), findsWidgets);
    expect(find.text('即将回复'), findsOneWidget);
    // 回复预览不再叠「回复」角标（与副文案重复）。
    expect(find.text('回复'), findsNothing);
    expect(find.text('关闭'), findsNothing); // 默认测试视口为紧凑屏
    expect(find.byType(QuoteBlock), findsAtLeastNWidgets(1));
    expect(find.text('我的回复正文'), findsWidgets);
  });

  testWidgets('ComposeScreen preview appends post signature', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...buildOverrides(auth: _LoggedInAuthNotifier.new),
          settingsProvider.overrideWith(
            () => SettingsNotifier(
              initial: const AppSettings(
                postSignatureEnabled: true,
                postSignatureShowDevice: true,
                postSignatureCustom: '摸鱼',
              ),
            ),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme('purple'),
          home: const ComposeScreen(tid: '100', fid: '4'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '预览正文');
    await tester.pump();
    await tester.tap(find.byTooltip('预览'));
    await tester.pumpAndSettle();

    expect(find.text('预览正文'), findsWidgets);
    expect(find.textContaining('摸鱼'), findsWidgets);
    expect(find.textContaining('S1er 客户端'), findsWidgets);
    expect(find.textContaining('TestDevice'), findsWidgets);
  });

  testWidgets('ComposeScreen places send and image in bottom bar',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: buildOverrides(auth: _LoggedInAuthNotifier.new),
        child: MaterialApp(
          theme: AppTheme.lightTheme('purple'),
          home: const ComposeScreen(
            tid: '100',
            fid: '4',
            subject: '另一个主题',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AppBar), findsOneWidget);
    final appBar = tester.widget<AppBar>(find.byType(AppBar));
    expect(appBar.actions, isNull);

    expect(find.textContaining('主题 · 另一个主题'), findsOneWidget);
    expect(find.text('发送'), findsOneWidget);
    expect(find.text('图片'), findsOneWidget);
    expect(find.text('表情'), findsOneWidget);
    expect(find.byTooltip('预览'), findsOneWidget);
    expect(find.byIcon(Icons.image_outlined), findsOneWidget);
  });

  testWidgets('ComposeScreen emoticon panel inserts entity into editor',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: buildOverrides(auth: _LoggedInAuthNotifier.new),
        child: MaterialApp(
          theme: AppTheme.lightTheme('purple'),
          home: const ComposeScreen(tid: '100', fid: '4'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('表情'));
    await tester.pumpAndSettle();
    expect(find.text('麻将脸'), findsOneWidget);

    await tester.tap(find.byTooltip('[f:001]'));
    await tester.pump();

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller!.text, contains('[f:001]'));
  });

  testWidgets('ComposeScreen send disabled until message entered',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: buildOverrides(auth: _LoggedInAuthNotifier.new),
        child: MaterialApp(
          theme: AppTheme.lightTheme('purple'),
          home: const ComposeScreen(tid: '100', fid: '4'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final sendFinder = find.widgetWithText(FilledButton, '发送');
    expect(tester.widget<FilledButton>(sendFinder).onPressed, isNull);

    await tester.enterText(find.byType(TextField), 'hello');
    await tester.pump();
    expect(tester.widget<FilledButton>(sendFinder).onPressed, isNotNull);

    await tester.enterText(find.byType(TextField), '   ');
    await tester.pump();
    final clearedSend = tester.widget<FilledButton>(sendFinder);
    expect(clearedSend.onPressed, isNull);
  });

  testWidgets('ComposeScreen expands subject on tap', (tester) async {
    const longSubject = '很长的主题标题用于测试展开折叠行为一二三四五六七八九十';
    await tester.pumpWidget(
      ProviderScope(
        overrides: buildOverrides(auth: _LoggedInAuthNotifier.new),
        child: MaterialApp(
          theme: AppTheme.lightTheme('purple'),
          home: const ComposeScreen(
            tid: '100',
            fid: '4',
            subject: longSubject,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.expand_more), findsOneWidget);
    await tester.tap(find.textContaining('主题 ·'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.expand_less), findsOneWidget);
  });

  testWidgets('ComposeScreen shows short image chip for long img bbcode',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: buildOverrides(auth: _LoggedInAuthNotifier.new),
        child: MaterialApp(
          theme: AppTheme.lightTheme('purple'),
          home: const ComposeScreen(tid: '100', fid: '4'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    const longName = 'QQ截图20260714142502_extra_long_filename.webp';
    await tester.enterText(
      find.byType(TextField),
      '[img]https://p.sda1.dev/33/abc/$longName[/img]',
    );
    await tester.pump();

    expect(find.text('图片 1'), findsOneWidget);
    expect(find.text(longName), findsNothing);
    expect(find.byType(InputChip), findsOneWidget);
  });

  testWidgets('ComposeScreen deletes chip and removes img bbcode',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: buildOverrides(auth: _LoggedInAuthNotifier.new),
        child: MaterialApp(
          theme: AppTheme.lightTheme('purple'),
          home: const ComposeScreen(tid: '100', fid: '4'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextField),
      'x[img]https://example.com/a.png[/img]y',
    );
    await tester.pump();
    expect(find.text('图片 1'), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.byType(InputChip),
        matching: find.byIcon(Icons.close),
      ),
    );
    await tester.pump();

    expect(find.text('图片 1'), findsNothing);
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller!.text.contains('[img]'), isFalse);
  });

  testWidgets('ComposeScreen redirects to login when not authenticated',
      (tester) async {
    final router = GoRouter(
      initialLocation: '/compose',
      routes: [
        GoRoute(
          path: '/compose',
          builder: (context, state) => const ComposeScreen(
            tid: '100',
            fid: '4',
          ),
        ),
        GoRoute(
          path: '/login',
          builder: (context, state) => const Scaffold(
            body: Center(child: Text('Login Page')),
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: buildOverrides(auth: _LoggedOutAuthNotifier.new),
        child: MaterialApp.router(
          theme: AppTheme.lightTheme('purple'),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Login Page'), findsOneWidget);
  });

  testWidgets('ComposeScreen without tid shows error state', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: buildOverrides(auth: _LoggedInAuthNotifier.new),
        child: MaterialApp(
          theme: AppTheme.lightTheme('purple'),
          home: const ComposeScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('无法回复'), findsOneWidget);
    expect(find.textContaining('暂不支持从此处回复'), findsOneWidget);
  });

  testWidgets('ComposeScreen constrains form width on wide screens',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: buildOverrides(auth: _LoggedInAuthNotifier.new),
        child: MaterialApp(
          theme: AppTheme.lightTheme('purple'),
          home: const ComposeScreen(tid: '100', fid: '4'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('compose_desktop_card')), findsOneWidget);
    // standard 限宽 1040，Card 左右各 24 padding。
    expect(
      tester.getSize(find.byType(TextField).first).width,
      S1Breakpoints.contentWidthLarge - 48,
    );
  });
}

class _StubComposeController extends ComposeController {
  _StubComposeController(super.ref);

  @override
  Future<QuoteInfo?> prefetchQuote({
    required String tid,
    required String pid,
  }) async {
    return const QuoteInfo(
      noticeAuthor: 'encoded',
      noticeTrimStr:
          '[quote][url=forum.php?mod=redirect&goto=findpost&pid=42&ptid=100]'
          'alice 发表于 2024[/url]\nquoted body[/quote]',
    );
  }

  @override
  Future<ReplySubmitResult> submitReply({
    required String tid,
    required String fid,
    required String message,
    QuoteInfo? quoteInfo,
    Post? quotedPost,
  }) async {
    return ReplySubmitResult(pid: '1', tid: tid);
  }

  @override
  Future<NewThreadFormInfo> fetchNewThreadForm({required String fid}) async {
    return const NewThreadFormInfo(
      threadTypes: {'1': '其他'},
      typeRequired: true,
      formhash: 'fixture',
    );
  }
}

class _LoggedInAuthNotifier extends AuthNotifier {
  @override
  AuthState build() => AuthState(isLoggedIn: true, username: 'tester');
}

class _LoggedOutAuthNotifier extends AuthNotifier {
  @override
  AuthState build() => AuthState();
}
