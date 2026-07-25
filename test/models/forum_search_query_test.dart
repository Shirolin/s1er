import 'package:flutter_test/flutter_test.dart';
import 'package:s1er/models/forum_search_query.dart';

void main() {
  group('ForumSearchQuery', () {
    test('empty query is default and validates with keyword requirement', () {
      const query = ForumSearchQuery.empty;
      expect(query.isDefault, isTrue);
      expect(query.activeFilterCount, 0);
      expect(query.validate(), '请输入关键词或作者');
      expect(query.toPostFields(), {
        'srchtxt': '',
        'searchsubmit': 'yes',
      });
    });

    test('keyword-only quick search omits advanced fields', () {
      const query = ForumSearchQuery(keyword: 'switch');
      expect(query.isDefault, isTrue);
      expect(query.validate(), isNull);
      expect(query.toPostFields(), {
        'srchtxt': 'switch',
        'searchsubmit': 'yes',
      });
    });

    test('author-only search is allowed and sends forum scope all', () {
      const query = ForumSearchQuery(author: 'alice');
      expect(query.validate(), isNull);
      expect(query.toPostFields(), {
        'srchtxt': '',
        'searchsubmit': 'yes',
        'srchuname': 'alice',
        'srchfid': ['all'],
      });
      expect(query.activeFilterCount, 1);
    });

    test('full advanced fields map to Discuz POST names', () {
      const query = ForumSearchQuery(
        keyword: 'switch',
        author: 'bob',
        filter: ForumSearchFilter.digest,
        specials: {1, 3},
        srchfromSeconds: 604800,
        before: true,
        orderby: 'views',
        ascending: true,
        forumIds: {'4', '6'},
      );

      expect(query.toPostFields(), {
        'srchtxt': 'switch',
        'searchsubmit': 'yes',
        'srchuname': 'bob',
        'srchfilter': 'digest',
        'special': ['1', '3'],
        'srchfrom': '604800',
        'before': '1',
        'orderby': 'views',
        'ascdesc': 'asc',
        'srchfid': ['4', '6'],
      });
      expect(query.activeFilterCount, 7);
      expect(query.isDefault, isFalse);
    });

    test('trade special switches order options and normalizes orderby', () {
      const query = ForumSearchQuery(
        keyword: '手办',
        specials: {2},
        orderby: 'views',
      );
      expect(query.hasTradeSpecial, isTrue);
      expect(query.effectiveOrderby, 'dateline');
      expect(
        query.orderOptions.map((e) => e.value),
        ['dateline', 'price', 'expiration'],
      );
    });

    test('summaryParts lists active filters', () {
      const query = ForumSearchQuery(
        author: 'alice',
        filter: ForumSearchFilter.digest,
        srchfromSeconds: 86400,
        forumIds: {'4'},
      );
      expect(
        query.summaryParts(),
        ['作者: alice', '精华主题', '1 天以内', '1 个版块'],
      );
    });
  });
}
