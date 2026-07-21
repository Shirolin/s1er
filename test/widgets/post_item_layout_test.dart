import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s1er/models/post.dart';
import 'package:s1er/widgets/post_item.dart';

import '../helpers/test_theme.dart';

void main() {
  testWidgets('PostItem avoids header overflow under narrow constraints',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: wrapWithAppTheme(
          const SizedBox(
            width: 69,
            child: _NarrowPostHarness(),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byType(PostItem), findsOneWidget);
  });

  testWidgets('PostItem keeps alive after leaving ListView viewport',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        child: wrapWithAppTheme(
          ListView(
            children: [
              SizedBox(
                height: 400,
                child: PostItem(
                  post: Post.fromJson({
                    'pid': 'keep-1',
                    'message': 'heavy body',
                    'author': 'author',
                    'authorid': '1',
                    'dbdateline': '1700001000',
                    'number': '1',
                  }),
                ),
              ),
              const SizedBox(height: 800, child: Text('below')),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('heavy body'), findsOneWidget);

    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();

    // Offscreen but keep-alive: still in tree (not disposed/rebuilt from scratch).
    expect(find.text('heavy body', skipOffstage: false), findsOneWidget);
  });

  testWidgets('PostItem opens text selection sheet from menu',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: wrapWithAppTheme(
          MaterialApp(
            home: Scaffold(
              body: PostItem(
                post: Post.fromJson({
                  'pid': 'select-1',
                  'message': 'Selectable content text',
                  'author': 'author',
                  'authorid': '1',
                  'dbdateline': '1700001000',
                  'number': '1',
                }),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();

    expect(find.text('选择文字'), findsOneWidget);

    await tester.tap(find.text('选择文字'));
    await tester.pumpAndSettle();

    // Sheet header and content are displayed
    expect(find.text('选择文字'), findsWidgets);
    expect(find.text('Selectable content text'), findsWidgets);
  });
}

class _NarrowPostHarness extends StatelessWidget {
  const _NarrowPostHarness();

  @override
  Widget build(BuildContext context) {
    return PostItem(
      post: Post.fromJson({
        'pid': '1',
        'message': 'body',
        'author': 'a very long author name',
        'authorid': '1',
        'dbdateline': '1700001000',
        'number': '1',
      }),
    );
  }
}
