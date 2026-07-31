import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/s1_haptics.dart';
import '../utils/window_size.dart';
import 's1_adaptive_sheet_spec.dart';

/// Shared layout for sheets shown via [showS1AdaptiveSheet] presets.
class S1AdaptiveSheetScaffold extends StatelessWidget {
  const S1AdaptiveSheetScaffold({
    super.key,
    this.title,
    this.subtitle,
    this.headerTrailing,
    this.prominentTitle = false,
    this.children = const [],
    this.footer,
    this.scrollable = false,
    this.maxHeightFactor,
    this.includeHeaderDivider = true,
  });

  final String? title;
  final String? subtitle;
  final Widget? headerTrailing;
  final bool prominentTitle;
  final List<Widget> children;
  final Widget? footer;
  final bool scrollable;
  final double? maxHeightFactor;
  final bool includeHeaderDivider;

  bool get _hasHeader =>
      title != null || subtitle != null || headerTrailing != null;

  @override
  Widget build(BuildContext context) {
    final insets = S1AdaptiveSheetInsets.of(context);
    final maxHeight = maxHeightFactor == null
        ? null
        : MediaQuery.sizeOf(context).height * maxHeightFactor!;

    Widget body = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_hasHeader)
          S1AdaptiveSheetHeader(
            title: title,
            subtitle: subtitle,
            trailing: headerTrailing,
            prominentTitle: prominentTitle,
            includeDivider: includeHeaderDivider,
          ),
        if (scrollable && children.length == 1)
          Flexible(child: children.first)
        else if (scrollable)
          Flexible(
            child: SingleChildScrollView(child: Column(children: children)),
          )
        else
          ...children,
        if (footer != null) ...[
          const SizedBox(height: 8),
          footer!,
        ],
      ],
    );

    if (maxHeight != null) {
      body = ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: body,
      );
    }

    return SafeArea(
      child: Padding(
        padding: insets.content,
        child: body,
      ),
    );
  }
}

/// Title block with optional trailing widget (e.g. page-count badge).
class S1AdaptiveSheetHeader extends StatelessWidget {
  const S1AdaptiveSheetHeader({
    super.key,
    this.title,
    this.subtitle,
    this.trailing,
    this.prominentTitle = false,
    this.includeDivider = true,
  });

  final String? title;
  final String? subtitle;
  final Widget? trailing;
  final bool prominentTitle;
  final bool includeDivider;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDesktop = context.isExpandedOrAbove;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (title != null || trailing != null)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (title != null)
                Expanded(
                  child: Text(
                    title!,
                    style: S1AdaptiveSheetSpec.titleStyle(
                      context,
                      prominent: prominentTitle,
                    ),
                    maxLines: isDesktop ? 3 : 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              if (trailing != null) ...[
                if (title != null) const SizedBox(width: 12),
                trailing!,
              ],
            ],
          ),
        if (subtitle != null) ...[
          const SizedBox(height: 6),
          Text(
            subtitle!,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: S1AdaptiveSheetSpec.subtitleStyle(context),
          ),
        ],
        if (includeDivider) ...[
          const SizedBox(height: 12),
          Divider(height: 1, color: scheme.outlineVariant),
          SizedBox(height: isDesktop ? 8 : 4),
        ],
      ],
    );
  }
}

/// Scrollable form body with consistent section spacing.
class S1AdaptiveSheetBody extends StatelessWidget {
  const S1AdaptiveSheetBody({
    super.key,
    required this.child,
    this.sectionSpacing = 16,
  });

  final Widget child;
  final double sectionSpacing;

  @override
  Widget build(BuildContext context) {
    return child;
  }
}

/// Primary / secondary actions at sheet bottom.
class S1AdaptiveSheetFooter extends StatelessWidget {
  const S1AdaptiveSheetFooter({
    super.key,
    this.primaryLabel,
    this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
    this.primaryEnabled = true,
  });

  final String? primaryLabel;
  final VoidCallback? onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;
  final bool primaryEnabled;

  @override
  Widget build(BuildContext context) {
    final isDesktop = context.isExpandedOrAbove;

    if (isDesktop) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (secondaryLabel != null && onSecondary != null) ...[
            TextButton(onPressed: onSecondary, child: Text(secondaryLabel!)),
            const SizedBox(width: 8),
          ],
          if (primaryLabel != null && onPrimary != null)
            FilledButton(
              onPressed: primaryEnabled ? onPrimary : null,
              child: Text(primaryLabel!),
            ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (primaryLabel != null && onPrimary != null)
          FilledButton(
            onPressed: primaryEnabled ? onPrimary : null,
            child: Text(primaryLabel!),
          ),
        if (secondaryLabel != null && onSecondary != null) ...[
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: onSecondary,
            child: Text(secondaryLabel!),
          ),
        ],
      ],
    );
  }
}

/// Action row: compact [ListTile] on desktop, icon tile on mobile.
class S1AdaptiveActionTile extends StatelessWidget {
  const S1AdaptiveActionTile({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.subtitle,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    if (context.isExpandedOrAbove) {
      return _DesktopActionTile(
        icon: icon,
        label: label,
        subtitle: subtitle,
        onTap: onTap,
        destructive: destructive,
      );
    }
    return _MobileActionTile(
      icon: icon,
      label: label,
      subtitle: subtitle,
      onTap: onTap,
      destructive: destructive,
    );
  }
}

class _DesktopActionTile extends StatelessWidget {
  const _DesktopActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.subtitle,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final foreground = destructive ? scheme.error : scheme.onSurface;

    return ListTile(
      leading: Icon(
        icon,
        size: 24,
        color: destructive ? scheme.error : scheme.onSurfaceVariant,
      ),
      title: Text(
        label,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: foreground,
              fontWeight: FontWeight.w500,
            ),
      ),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
      visualDensity: VisualDensity.compact,
      contentPadding: EdgeInsets.zero,
      minVerticalPadding: 0,
      onTap: () {
        S1Haptics.selection();
        onTap();
      },
    );
  }
}

class _MobileActionTile extends StatelessWidget {
  const _MobileActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.subtitle,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final foreground = destructive ? scheme.error : scheme.onSurface;
    final iconBackground =
        destructive ? scheme.errorContainer : scheme.secondaryContainer;
    final iconColor =
        destructive ? scheme.onErrorContainer : scheme.onSecondaryContainer;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          S1Haptics.selection();
          onTap();
        },
        borderRadius: S1Shape.medium,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: iconBackground,
                  borderRadius: S1Shape.small,
                ),
                child: Icon(icon, size: 22, color: iconColor),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: textTheme.bodyLarge?.copyWith(
                        color: foreground,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
