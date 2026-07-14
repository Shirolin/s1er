import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s1_app/models/post.dart';
import 'package:s1_app/widgets/post_item.dart';

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
