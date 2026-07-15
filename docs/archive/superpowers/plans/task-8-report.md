# Task 8: BBCode Renderer Widget - Implementation Report

## What Was Implemented

Created 4 new widgets and 1 test file for rendering BBCode-formatted forum post content:

### Widgets
1. **EmoticonWidget** (`lib/widgets/emoticon_widget.dart`) - Renders emoticon images from bundled assets, with text fallback for unknown codes
2. **QuoteBlock** (`lib/widgets/quote_block.dart`) - Styled quote container with left border accent, recursively renders quoted content via BbcodeRenderer
3. **ImageViewer** (`lib/widgets/image_viewer.dart`) - Network image display with caching, loading indicator, and full-screen tap-to-zoom
4. **BbcodeRenderer** (`lib/widgets/bbcode_renderer.dart`) - Main renderer that parses BBCode, splits quote blocks, converts remaining content to HTML via BbcodeParser, and renders with flutter_html

### Tests
- **26 new tests** in `test/widgets/bbcode_renderer_test.dart`

## TDD Evidence

### RED Phase
Initial test run failed with compilation errors - all widget files missing:
```
Error: Error when reading 'lib/widgets/emoticon_widget.dart': 系統找不到指定的文件。
Error: Error when reading 'lib/widgets/quote_block.dart': 系統找不到指定的文件。
Error: Error when reading 'lib/widgets/bbcode_renderer.dart': 系統找不到指定的文件。
```

### GREEN Phase
All 26 tests pass, plus all 78 existing tests remain passing (105 total).

## Files Changed

| File | Action |
|------|--------|
| `lib/widgets/emoticon_widget.dart` | Created |
| `lib/widgets/quote_block.dart` | Created |
| `lib/widgets/image_viewer.dart` | Created |
| `lib/widgets/bbcode_renderer.dart` | Created |
| `test/widgets/bbcode_renderer_test.dart` | Created |

## Self-Review Findings

### Deviation from Plan
The plan specified using `flutter_html`'s `customRender` API (v2 style), but the installed version is flutter_html 3.0.0 which uses `HtmlExtension`/`TagExtension` instead. I adapted the implementation accordingly:
- Replaced `customRender` map with `extensions: [TagExtension(...)]`
- TagExtension builder returns `Widget` (not `WidgetSpan`) - the package wraps with WidgetSpan internally

### Dart-Specific Issue
The plan used `String.split(regex)` assuming captured groups would appear in the result (JavaScript behavior). Dart's `split` does NOT include captured groups. I rewrote the parsing to use `RegExp.allMatches()` + manual substring extraction instead.

### Test Adjustments
- QuoteBlock internally creates a BbcodeRenderer, so BbcodeRenderer counts are higher than expected in nested scenarios - adjusted test expectations accordingly

## Commit
```
0170bee feat: BBCode renderer, emoticon, quote block, image viewer widgets
```
