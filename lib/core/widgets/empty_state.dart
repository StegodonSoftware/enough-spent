import 'package:flutter/material.dart';

/// A centered empty state with an illustration, message, and optional CTA.
///
/// Used when lists have no data to display.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Responsive sizing based on available height
        final availableHeight = constraints.maxHeight;
        final isConstrained = availableHeight < 200;

        // Adjust sizes for constrained spaces to fit within tight constraints
        final iconSize = isConstrained ? 48.0 : 96.0;
        final iconInnerSize = isConstrained ? 24.0 : 48.0;
        final verticalPadding = isConstrained ? 8.0 : 32.0;
        final horizontalPadding = isConstrained ? 12.0 : 32.0;
        final spacing = isConstrained ? 6.0 : 24.0;
        final subtitleSpacing = isConstrained ? 2.0 : 8.0;

        return Center(
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: horizontalPadding,
              vertical: verticalPadding,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Illustration container
                Container(
                  width: iconSize,
                  height: iconSize,
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    size: iconInnerSize,
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                  ),
                ),

                SizedBox(height: spacing),

                // Title
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),

                // Subtitle
                if (subtitle != null) ...[
                  SizedBox(height: subtitleSpacing),
                  Text(
                    subtitle!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],

                // CTA Button
                if (actionLabel != null && onAction != null) ...[
                  SizedBox(height: spacing),
                  FilledButton.tonal(
                    onPressed: onAction,
                    child: Text(actionLabel!),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
