import 'package:flutter/material.dart';

import '../../../currency/formatters/currency_formatter.dart';
import '../../../currency/models/currency.dart';

/// Individual category with proportional fill bar and details.
///
/// Displays a category's spending as a percentage of total,
/// with a color indicator, fill bar, and formatted amount.
class CategoryProportionRow extends StatelessWidget {
  final String categoryName;
  final Color color;
  final int totalMinor;
  final double percentage;
  final Currency currency;
  final bool isOther;

  static const double _indicatorWidth = 8.0;
  static const double _indicatorHeight = 40.0;
  static const double _barHeight = 8.0;
  static const double _barBorderRadius = 4.0;

  const CategoryProportionRow({
    super.key,
    required this.categoryName,
    required this.color,
    required this.totalMinor,
    required this.percentage,
    required this.currency,
    this.isOther = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final percentText = '${(percentage * 100).toStringAsFixed(1)}%';
    final amountText = CurrencyFormatter.formatMinor(totalMinor, currency);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Color indicator
          Container(
            width: _indicatorWidth,
            height: _indicatorHeight,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 12),
          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row: category name + percentage + amount
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        categoryName,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w500,
                          fontStyle: isOther ? FontStyle.italic : null,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      percentText,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                // Proportion bar
                _ProportionBar(
                  percentage: percentage,
                  color: color,
                  trackColor: colorScheme.surfaceContainerHighest,
                ),
                const SizedBox(height: 4),
                // Amount
                Text(
                  amountText,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProportionBar extends StatelessWidget {
  final double percentage;
  final Color color;
  final Color trackColor;

  const _ProportionBar({
    required this.percentage,
    required this.color,
    required this.trackColor,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final fillWidth = constraints.maxWidth * percentage.clamp(0.0, 1.0);

        return Container(
          height: CategoryProportionRow._barHeight,
          decoration: BoxDecoration(
            color: trackColor,
            borderRadius: BorderRadius.circular(CategoryProportionRow._barBorderRadius),
          ),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Container(
              width: fillWidth,
              height: CategoryProportionRow._barHeight,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(CategoryProportionRow._barBorderRadius),
              ),
            ),
          ),
        );
      },
    );
  }
}
