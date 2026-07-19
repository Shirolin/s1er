import 'package:flutter_test/flutter_test.dart';
import 'package:s1er/utils/edit_post_draft.dart';

void main() {
  test('edit draft stores editable fields without source baseline', () {
    final drafts = EditPostDraftStore.upsert(
      {},
      '200',
      subject: '新标题',
      message: '新正文',
      typeId: '1',
      readPerm: '0',
    );
    final parsed = EditPostDraftStore.parse(
      EditPostDraftStore.toStoreValue(drafts),
    );
    expect(parsed['200']?['message'], '新正文');
    expect(parsed['200']?.containsKey('sourceMessage'), isFalse);
  });

  test('remove clears only the requested post draft', () {
    final drafts = EditPostDraftStore.upsert(
      EditPostDraftStore.upsert(
        {},
        '200',
        subject: '',
        message: 'a',
      ),
      '201',
      subject: '',
      message: 'c',
    );
    final next = EditPostDraftStore.remove(drafts, '200');
    expect(next.containsKey('200'), isFalse);
    expect(next.containsKey('201'), isTrue);
  });
}
