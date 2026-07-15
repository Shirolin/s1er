# Task 5: HTML Parser Fallback — Implementation Report

## What Was Implemented

Two parser components for the S1 Flutter app:

### 1. `BbcodeParser` (`lib/utils/bbcode_parser.dart`)
Static utility class that converts BBCode markup to HTML. Supports:
- **Formatting**: `[b]`, `[i]`, `[u]`, `[s]` → `<b>`, `<i>`, `<u>`, `<s>`
- **Media**: `[img]url[/img]` → `<img src="url" />`
- **Links**: `[url=...]text[/url]` → `<a href="...">text</a>`, bare `[url]...[/url]`
- **Layout**: `[quote]` → `<blockquote>`, `[code]` → `<pre>`, `[*]` → `<li>`
- **Style**: `[color=...]` → inline `color:`, `[size=N]` → inline `font-size:`
- **Emoticons**: `[f:001]` → `<span class="emoticon" data-code="f:001">[emoticon]</span>`
- **Utilities**: `extractImages(html)`, `stripTags(html)`, HTML entity escaping
- Handles nested tags and empty input gracefully.

### 2. `HtmlParserService` (`lib/services/html_parser_service.dart`)
Fallback parser that extracts structured data from Discuz HTML pages when the JSON API fails. Provides both static methods (testable without network) and instance methods (fetch + parse):

| Static Method | Purpose |
|---|---|
| `parseThreadListHtml(html, fid)` | Extracts threads from forum display HTML |
| `parsePostListHtml(html)` | Extracts posts from thread detail HTML |
| `extractFormhash(html)` | Extracts CSRF formhash from hidden input |

Instance methods `getThreadList()`, `getPosts()`, `getFormhash()` fetch HTML via `S1HttpClient` then delegate to the static parsers.

## TDD Evidence

### RED Phase
```
Error when reading 'lib/utils/bbcode_parser.dart': 系統找不到指定的文件。
Error when reading 'lib/services/html_parser_service.dart': 系統找不到指定的文件。
```
All 28 tests failed with import errors — source files did not exist yet.

### GREEN Phase
```
00:01 +70: All tests passed!
```
28 new parser tests + 42 existing tests = 70 total, all green.

## Files Changed

| File | Action |
|---|---|
| `lib/utils/bbcode_parser.dart` | Created — BBCode-to-HTML converter |
| `lib/services/html_parser_service.dart` | Created — HTML parser fallback service |
| `test/services/html_parser_test.dart` | Created — 28 tests across 4 groups |

## Test Breakdown

| Group | Tests | Covers |
|---|---|---|
| BbcodeParser | 20 | All tag types, nesting, escaping, extractImages, stripTags |
| HtmlParserService - Thread List | 4 | Single/multi thread parsing, empty HTML, missing author |
| HtmlParserService - Post List | 2 | Post extraction with authors, empty case |
| HtmlParserService - Formhash | 2 | Extraction from form, missing formhash |

## Self-Review Findings

1. **DOM traversal for parent lookup**: The `html` package lacks `Element.closest()`. Implemented manual parent walk (`element.parent`) to find ancestor `#post_*` containers — correct and idiomatic for this package.

2. **Selector precision**: Initial post selector `.message, .postmessage` matched both containers and children (double-counting). Fixed to `#postlist > div[id^="post_"]` for precise container-only matching.

3. **Static + instance pattern**: Static parsing methods allow pure unit tests without mocking HTTP. Instance methods add network fetch + parse for production use.

## Concerns

- The Discuz HTML selectors (`li[id^="normalthread_"]`, `#postlist > div[id^="post_"]`) are based on standard Discuz X3 layouts. If the target forum uses a custom theme, selectors may need adjustment — but this is expected for a fallback parser.
- The `html` package is unmaintained (last pub.dev update 2023). It works fine for Discuz HTML but won't receive security patches. Acceptable for a local parsing utility.
