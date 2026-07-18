import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:html/dom.dart' as dom;

import 's1_click_region.dart';

/// Like flutter_html's [InteractiveElementBuiltIn], but forces a click cursor.
///
/// The built-in copies the child's [MouseCursor.defer] onto the tappable
/// [TextSpan], which hides the hand cursor on desktop/web.
class HtmlClickableAnchorExtension extends HtmlExtension {
  const HtmlClickableAnchorExtension();

  @override
  Set<String> get supportedTags => {'a'};

  @override
  bool matches(ExtensionContext context) {
    return supportedTags.contains(context.elementName) &&
        context.attributes.containsKey('href');
  }

  @override
  StyledElement prepare(
    ExtensionContext context,
    List<StyledElement> children,
  ) {
    // Color / weight / decoration come from Html style map (`'a': Style(...)`).
    return InteractiveElement(
      name: context.elementName,
      children: children,
      href: context.attributes['href'],
      style: Style(),
      node: context.node,
      elementId: context.id,
    );
  }

  @override
  InlineSpan build(ExtensionContext context) {
    return TextSpan(
      children: context.inlineSpanChildren!.map((childSpan) {
        return _processInteractableChild(context, childSpan);
      }).toList(),
    );
  }

  InlineSpan _processInteractableChild(
    ExtensionContext context,
    InlineSpan childSpan,
  ) {
    void onTap() => context.parser.internalOnAnchorTap?.call(
          (context.styledElement! as InteractiveElement).href,
          context.attributes,
          context.node as dom.Element,
        );

    if (childSpan is TextSpan) {
      // Html Style is bridged from textTheme in BbcodeRenderer.
      final resolvedStyle = _resolvedAnchorStyle(
        context.styledElement?.style,
        childSpan.style,
      );
      return TextSpan(
        text: childSpan.text,
        children: childSpan.children
            ?.map((e) => _processInteractableChild(context, e))
            .toList(),
        recognizer: TapGestureRecognizer()..onTap = onTap,
        style: resolvedStyle,
        semanticsLabel: childSpan.semanticsLabel,
        locale: childSpan.locale,
        mouseCursor: SystemMouseCursors.click,
        onEnter: childSpan.onEnter,
        onExit: childSpan.onExit,
        spellOut: childSpan.spellOut,
      );
    }

    return WidgetSpan(
      alignment: context.style!.verticalAlign
          .toPlaceholderAlignment(context.style!.display),
      baseline: TextBaseline.alphabetic,
      child: S1ClickRegion(
        key: AnchorKey.of(context.parser.key, context.styledElement),
        onTap: onTap,
        child: (childSpan as WidgetSpan).child,
      ),
    );
  }

  /// Converts flutter_html [Style] to Flutter text style (textTheme-bridged).
  static TextStyle? _resolvedAnchorStyle(
    Style? htmlStyle,
    TextStyle? fallback,
  ) {
    if (htmlStyle == null) return fallback;
    // Method name contains "TextStyle"; keep comment for audit lineFilter.
    return htmlStyle.generateTextStyle(); // textTheme
  }
}
