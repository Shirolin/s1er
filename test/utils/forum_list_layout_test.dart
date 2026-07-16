import 'package:flutter_test/flutter_test.dart';
import 'package:s1_app/utils/forum_list_layout.dart';

void main() {
  group('forum list-detail layout', () {
    test('1199dp keeps standalone thread navigation', () {
      expect(shouldOpenForumThreadInPlace(1199), isFalse);
      expect(
        shouldShowForumSplitView(1199, hasSelectedThread: true),
        isFalse,
      );
    });

    test('1200dp enables in-place open before a thread is selected', () {
      expect(shouldOpenForumThreadInPlace(1200), isTrue);
      expect(
        shouldShowForumSplitView(1200, hasSelectedThread: false),
        isFalse,
      );
    });

    test('1200dp shows split view after selection', () {
      expect(
        shouldShowForumSplitView(1200, hasSelectedThread: true),
        isTrue,
      );
    });

    test('list pane width is responsive and bounded', () {
      expect(forumListPaneWidth(1000), 420);
      expect(forumListPaneWidth(1280), closeTo(486.4, 0.01));
      expect(forumListPaneWidth(1600), 520);
    });
  });
}
