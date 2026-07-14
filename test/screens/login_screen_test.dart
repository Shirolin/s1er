import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s1_app/config/login_security_questions.dart';
import 'package:s1_app/screens/login_screen.dart';
import 'package:s1_app/theme/app_theme.dart';

void main() {
  testWidgets('login screen shows answer field after picking a question',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.lightTheme('purple'),
          home: const LoginScreen(),
        ),
      ),
    );

    expect(find.text('安全提问'), findsOneWidget);
    expect(find.text('答案'), findsNothing);

    await tester.tap(find.byType(DropdownMenu<int>));
    await tester.pumpAndSettle();

    await tester.tap(find.text(LoginSecurityQuestions.byId(1).label).last);
    await tester.pumpAndSettle();

    expect(find.text('答案'), findsOneWidget);
  });

  testWidgets('login requires answer when security question is set',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.lightTheme('purple'),
          home: const LoginScreen(),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField).at(0), 'alice');
    await tester.enterText(find.byType(TextField).at(1), 'secret');

    await tester.tap(find.byType(DropdownMenu<int>));
    await tester.pumpAndSettle();
    await tester.tap(find.text(LoginSecurityQuestions.byId(1).label).last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('登录'));
    await tester.pump();

    expect(find.text('请填写安全提问的答案'), findsOneWidget);
  });
}
