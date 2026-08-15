import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s1er/theme/app_theme.dart';
import 'package:s1er/widgets/skeleton/forum_index_skeleton.dart';
import 'package:s1er/widgets/skeleton/list_row_skeleton.dart';
import 'package:s1er/widgets/skeleton/post_item_skeleton.dart';
import 'package:s1er/widgets/skeleton/s1_async_list_loading.dart';
import 'package:s1er/widgets/skeleton/s1_viewport_skeleton_list.dart';
import 'package:s1er/widgets/skeleton/thread_card_skeleton.dart';
import 'package:s1er/widgets/thread_locate_skeleton.dart';

void main() {
  Widget wrap(Widget child) {
    return ProviderScope(
      child: MaterialApp(
        theme: AppTheme.lightTheme('purple'),
        home: Scaffold(body: child),
      ),
    );
  }

  testWidgets('S1ViewportSkeletonList fills viewport by estimated height',
      (tester) async {
    await tester.pumpWidget(
      wrap(
        const SizedBox(
          height: 400,
          child: S1ViewportSkeletonList(
            estimatedItemHeight: 100,
            itemBuilder: _skeletonItem,
          ),
        ),
      ),
    );

    expect(find.byType(S1ViewportSkeletonList), findsOneWidget);
    expect(find.text('skeleton-item'), findsNWidgets(4));
  });

  testWidgets('list skeleton widgets pump without error', (tester) async {
    const widgets = <Widget>[
      S1AsyncListLoading(child: PostItemSkeletonList()),
      ThreadCardSkeletonList(),
      ListRowSkeletonList(),
      ForumIndexSkeleton(),
      ThreadLocateSkeleton(),
      PostItemSkeleton(),
      ThreadCardSkeleton(),
      ListRowSkeleton(),
    ];

    for (final widget in widgets) {
      await tester.pumpWidget(wrap(SizedBox(height: 600, child: widget)));
      await tester.pump();
    }
  });
}

Widget _skeletonItem(BuildContext context, int index) {
  return const SizedBox(
    height: 100,
    child: Center(child: Text('skeleton-item')),
  );
}
