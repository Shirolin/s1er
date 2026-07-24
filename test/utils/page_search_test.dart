import 'package:flutter_test/flutter_test.dart';
import 'package:s1er/utils/page_search.dart';

void main() {
  group('PageSearch.normalizeQuery', () {
    test('trims whitespace', () {
      expect(PageSearch.normalizeQuery('  hi  '), 'hi');
    });

    test('empty stays empty', () {
      expect(PageSearch.normalizeQuery('   '), '');
    });
  });

  group('PageSearch.matchesQuery', () {
    test('empty query matches anything', () {
      expect(PageSearch.matchesQuery('anything', ''), isTrue);
      expect(PageSearch.matchesQuery('', '  '), isTrue);
    });

    test('case insensitive contains', () {
      expect(PageSearch.matchesQuery('Hello World', 'hello'), isTrue);
      expect(PageSearch.matchesQuery('Hello World', 'WORLD'), isTrue);
      expect(PageSearch.matchesQuery('Hello World', 'xyz'), isFalse);
    });
  });

  group('PageSearch.filterByQuery', () {
    test('empty query returns all', () {
      final items = ['a', 'b'];
      expect(
        PageSearch.filterByQuery(items, '', (s) => [s]),
        items,
      );
    });

    test('keeps items with any matching field', () {
      final items = [
        ('alpha', 'one'),
        ('beta', 'two'),
        ('gamma', 'alpha'),
      ];
      final filtered = PageSearch.filterByQuery(
        items,
        'alpha',
        (e) => [e.$1, e.$2],
      );
      expect(filtered, [items[0], items[2]]);
    });
  });

  group('PageSearch.highlightHtml', () {
    test('empty query returns original', () {
      const html = '<p>Hello</p>';
      expect(PageSearch.highlightHtml(html, ''), html);
      expect(PageSearch.highlightHtml(html, '  '), html);
    });

    test('wraps text matches in mark', () {
      expect(
        PageSearch.highlightHtml('<p>Hello world</p>', 'world'),
        '<p>Hello <mark>world</mark></p>',
      );
    });

    test('case insensitive wrap preserves original case', () {
      expect(
        PageSearch.highlightHtml('Foo BAR baz', 'bar'),
        'Foo <mark>BAR</mark> baz',
      );
    });

    test('does not match inside tags or attributes', () {
      const html = '<a href="search.html" class="search">link</a>';
      expect(
        PageSearch.highlightHtml(html, 'search'),
        '<a href="search.html" class="search">link</a>',
      );
    });

    test('does not rematch inside existing mark', () {
      const html = '<mark>foo</mark> and foo';
      expect(
        PageSearch.highlightHtml(html, 'foo'),
        '<mark>foo</mark> and <mark>foo</mark>',
      );
    });

    test('multiple matches in one text node', () {
      expect(
        PageSearch.highlightHtml('aa aa', 'aa'),
        '<mark>aa</mark> <mark>aa</mark>',
      );
    });
  });
}
