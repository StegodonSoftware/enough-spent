import 'package:flutter/material.dart';
import 'package:dotted_border/dotted_border.dart';

import '../expense_constants.dart';

/// A reusable collapsible section header for expense lists.
///
/// Provides consistent styling for both date-grouped and category-grouped
/// transaction lists, with visual distinction for collapsed/expanded states.
class CollapsibleSectionHeader extends StatelessWidget {
  final Widget leading;
  final String title;
  final String? subtitle;
  final String? trailing;
  final int itemCount;
  final bool isExpanded;
  final VoidCallback onToggle;

  /// Whether to pin this header when its section is expanded.
  ///
  /// Set to false for tabs that allow multiple simultaneous expansions, where
  /// pinning all expanded headers would cause them to stack and crowd the view.
  final bool pinWhenExpanded;

  const CollapsibleSectionHeader({
    super.key,
    required this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    required this.itemCount,
    required this.isExpanded,
    required this.onToggle,
    this.pinWhenExpanded = true,
  });

  @override
  Widget build(BuildContext context) {
    return SliverPersistentHeader(
      pinned: pinWhenExpanded && isExpanded,
      delegate: _CollapsibleSectionHeaderDelegate(
        leading: leading,
        title: title,
        subtitle: subtitle,
        trailing: trailing,
        itemCount: itemCount,
        isExpanded: isExpanded,
        onToggle: onToggle,
      ),
    );
  }
}

class _CollapsibleSectionHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget leading;
  final String title;
  final String? subtitle;
  final String? trailing;
  final int itemCount;
  final bool isExpanded;
  final VoidCallback onToggle;

  // Subtitle height when present and expanded
  static const double subtitleHeight = 18.0;
  static const double subtitlePadding = 4.0;

  const _CollapsibleSectionHeaderDelegate({
    required this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    required this.itemCount,
    required this.isExpanded,
    required this.onToggle,
  });

  bool get _shouldShowSubtitle => subtitle != null && isExpanded;

  @override
  double get minExtent {
    // When a subtitle is visible, lock min == max so the header never
    // compresses while pinned — prevents content clipping in the main row.
    if (_shouldShowSubtitle) return maxExtent;
    return ExpenseLayout.categoryHeaderHeight;
  }

  @override
  double get maxExtent {
    if (_shouldShowSubtitle) {
      return ExpenseLayout.categoryHeaderHeight +
          subtitleHeight +
          subtitlePadding;
    }
    return ExpenseLayout.categoryHeaderHeight;
  }

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final isCollapsed = !isExpanded;

    // Background color logic:
    // - Pinned with content behind it: surfaceContainerLow with elevation
    // - Collapsed (not pinned): subtle tint to show it's collapsed
    // - Expanded (not pinned): scaffold background (blends in)
    Color backgroundColor;
    double elevation;

    if (overlapsContent) {
      backgroundColor = colorScheme.surfaceContainerLow;
      elevation = 1;
    } else if (isCollapsed) {
      backgroundColor = colorScheme.surfaceContainerLowest;
      elevation = 0;
    } else {
      backgroundColor = theme.scaffoldBackgroundColor;
      elevation = 0;
    }

    return SizedBox.expand(
      child: Material(
        color: backgroundColor,
        elevation: elevation,
        child: InkWell(
          onTap: onToggle,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Expand/collapse chevron
                AnimatedRotation(
                  turns: isExpanded ? 0 : -0.25,
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  child: Icon(
                    Icons.expand_more,
                    size: 20,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 8),

                // Leading widget (category color, icon, etc.)
                leading,
                const SizedBox(width: 10),

                // Title + optional subtitle — expands to fill available width.
                // Both lines are centered as a unit against the right-side widgets.
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: colorScheme.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (_shouldShowSubtitle) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // Item count badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$itemCount',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),

                // Trailing text (total amount)
                if (trailing != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    trailing!,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _CollapsibleSectionHeaderDelegate oldDelegate) {
    return oldDelegate.title != title ||
        oldDelegate.subtitle != subtitle ||
        oldDelegate.trailing != trailing ||
        oldDelegate.itemCount != itemCount ||
        oldDelegate.isExpanded != isExpanded;
  }
}

/// A colored vertical bar indicator for category identification.
///
/// Uses an 8px wide vertical bar style (end cap) for consistency
/// with expense tile indicators throughout the app.
class CategoryColorIndicator extends StatelessWidget {
  final Color color;
  final bool isSolid;

  const CategoryColorIndicator({
    super.key,
    required this.color,
    this.isSolid = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!isSolid) {
      return Container(
        margin: const EdgeInsets.only(right: 12),
        child: DottedBorder(
          options: RoundedRectDottedBorderOptions(
            dashPattern: const [8, 4],
            strokeWidth: 2,
            color: color,
            radius: const Radius.circular(3),
          ),
          child: Container(
            width: 7,
            height: 37,
            // no color = transparent
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(3)),
          ),
        ),
      );
    }
    return Container(
      width: 12,
      height: 40,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }
}
