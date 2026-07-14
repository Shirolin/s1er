import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:s1_app/models/post.dart';
import 'package:s1_app/models/quote_info.dart';
import 'package:s1_app/models/reply_submit_result.dart';
import 'package:s1_app/providers/auth_provider.dart';
import 'package:s1_app/providers/compose_provider.dart';
import 'package:s1_app/screens/compose_screen.dart';
import 'package:s1_app/theme/app_theme.dart';
import 'package:s1_app/utils/compose_draft_store.dart';

void main() {
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
        overrides: [
          authStateProvider.overrideWith(_LoggedInAuthNotifier.new),
          composeControllerProvider.overrideWith(
            (ref) => _StubComposeController(ref),
          ),
        ],
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

  testWidgets('ComposeScreen places send and image in bottom bar',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith(_LoggedInAuthNotifier.new),
          composeControllerProvider.overrideWith(
            (ref) => _StubComposeController(ref),
          ),
        ],
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
        overrides: [
          authStateProvider.overrideWith(_LoggedInAuthNotifier.new),
          composeControllerProvider.overrideWith(
            (ref) => _StubComposeController(ref),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme('purple'),
          home: const ComposeScreen(tid: '100', fid: '4'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('表情'));
    await tester.pumpAndSettle();

    expect(find.text('麻将脸'), findsWidgets);
    expect(find.text('键盘'), findsOneWidget);

    await tester.tap(find.byTooltip('[f:001]'));
    await tester.pump();

    expect(find.text('[f:001]'), findsOneWidget);
  });

  testWidgets('ComposeScreen disables send when message is empty',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith(_LoggedInAuthNotifier.new),
          composeControllerProvider.overrideWith(
            (ref) => _StubComposeController(ref),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme('purple'),
          home: const ComposeScreen(tid: '100', fid: '4'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final emptySend = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(emptySend.onPressed, isNull);

    await tester.enterText(find.byType(TextField), 'hello');
    await tester.pump();

    final filledSend = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(filledSend.onPressed, isNotNull);

    await tester.enterText(find.byType(TextField), '   ');
    await tester.pump();

    final clearedSend = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(clearedSend.onPressed, isNull);
  });

  testWidgets('ComposeScreen expands subject on tap', (tester) async {
    const longSubject =
        '很长的主题标题用于测试展开折叠行为一二三四五六七八九十';
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith(_LoggedInAuthNotifier.new),
          composeControllerProvider.overrideWith(
            (ref) => _StubComposeController(ref),
          ),
        ],
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
        overrides: [
          authStateProvider.overrideWith(_LoggedInAuthNotifier.new),
          composeControllerProvider.overrideWith(
            (ref) => _StubComposeController(ref),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme('purple'),
          home: const ComposeScreen(tid: '100', fid: '4'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    const longName =
        'QQ截图20260714142502_extra_long_filename.webp';
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
        overrides: [
          authStateProvider.overrideWith(_LoggedInAuthNotifier.new),
          composeControllerProvider.overrideWith(
            (ref) => _StubComposeController(ref),
          ),
        ],
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
        overrides: [
          authStateProvider.overrideWith(_LoggedOutAuthNotifier.new),
          composeControllerProvider.overrideWith(
            (ref) => _StubComposeController(ref),
          ),
        ],
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
        overrides: [
          authStateProvider.overrideWith(_LoggedInAuthNotifier.new),
          composeControllerProvider.overrideWith(
            (ref) => _StubComposeController(ref),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme('purple'),
          home: const ComposeScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('无法回复'), findsOneWidget);
    expect(find.textContaining('仅支持回复已有主题'), findsOneWidget);
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
          '[post][url=forum.php?mod=redirect&goto=findpost&pid=42&ptid=100]x[/url][/post]',
    );
  }

  @override
  Future<ReplySubmitResult> submitReply({
    required String tid,
    required String fid,
    required String message,
    QuoteInfo? quoteInfo,
  }) async {
    return ReplySubmitResult(pid: '1', tid: tid);
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
