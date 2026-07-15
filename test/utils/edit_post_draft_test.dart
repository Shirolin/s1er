import 'package:flutter_test/flutter_test.dart';
import 'package:s1_app/utils/edit_post_draft.dart';

void main() {
  test('edit draft stores editable fields and server baseline', () {
    final drafts = EditPostDraftStore.upsert(
      {},
      '200',
      subject: '新标题',
      message: '新正文',
      typeId: '1',
      readPerm: '0',
      sourceSubject: '原标题',
      sourceMessage: '原正文',
      sourceTypeId: '1',
      sourceReadPerm: '0',
    );
    final parsed = EditPostDraftStore.parse(
      EditPostDraftStore.toStoreValue(drafts),
    );
    expect(parsed['200']?['message'], '新正文');
    expect(parsed['200']?['sourceMessage'], '原正文');
  });

  test('remove clears only the requested post draft', () {
    final drafts = EditPostDraftStore.upsert(
      EditPostDraftStore.upsert(
        {},
        '200',
        subject: '',
        message: 'a',
        sourceSubject: '',
        sourceMessage: 'b',
      ),
      '201',
      subject: '',
      message: 'c',
      sourceSubject: '',
      sourceMessage: 'd',
    );
    final next = EditPostDraftStore.remove(drafts, '200');
    expect(next.containsKey('200'), isFalse);
    expect(next.containsKey('201'), isTrue);
  });
}
