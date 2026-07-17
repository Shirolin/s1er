import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s1er/models/edit_post_form_info.dart';
import 'package:s1er/models/edit_post_submit_result.dart';
import 'package:s1er/providers/auth_provider.dart';
import 'package:s1er/providers/compose_provider.dart';
import 'package:s1er/providers/settings_provider.dart';
import 'package:s1er/screens/compose_screen.dart';
import 'package:s1er/services/app_database.dart';
import 'package:s1er/services/app_local_data.dart';
import 'package:s1er/theme/app_theme.dart';

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
}

class _EditComposeController extends ComposeController {
  _EditComposeController(super.ref);

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

class _LoggedInAuthNotifier extends AuthNotifier {
  @override
  AuthState build() => AuthState(isLoggedIn: true);
}
