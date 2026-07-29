import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s1er/theme/app_theme.dart';
import 'package:s1er/widgets/s1_system_bottom_inset.dart';

void main() {
  testWidgets('S1PageBody reserves system bottom inset', (tester) async {
    const inset = 48.0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme('purple'),
        home: MediaQuery(
          data: const MediaQueryData(padding: EdgeInsets.only(bottom: inset)),
          child: Scaffold(
            body: S1PageBody(
              child: ListView(
                children: const [Text('content')],
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.byType(S1SystemBottomInset), findsOneWidget);
    expect(tester.getSize(find.byType(S1SystemBottomInset)).height, inset);
    expect(find.text('content'), findsOneWidget);
  });
}
