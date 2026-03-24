import 'package:flutter/material.dart';

import '../../../currency/formatters/currency_formatter.dart';
import '../../../currency/models/currency.dart';

/// A single comparison item for the multi-bar comparison.
class ComparisonItem {
  final String label;
  final int valueMinor;
  final Color? color;
  final bool isHighlighted;

  const ComparisonItem({
    required this.label,
    required this.valueMinor,
    this.color,
    this.isHighlighted = false,
  });
}

/// Visual comparison of multiple values using proportional horizontal bars.
///
/// Displays stacked bars where width is proportional to the maximum value,
/// with labels and formatted amounts. Supports any number of bars.
class MultiComparisonBar extends StatelessWidget {
  final List<ComparisonItem> items;
  final Currency currency;

  static const double _barHeight = 24.0;
  static const double _barGap = 8.0;
  static const double _borderRadius = 6.0;
  static const double _minBarFraction = 0.05;

  const MultiComparisonBar({
    super.key,
    required this.items,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Find max value for proportional sizing
    final maxValue = items.fold(0, (max, item) =>
        item.valueMinor > max ? item.valueMinor : max);

    // Default colors: primary for first/highlighted, then progressively muted
    final defaultColors = [
      colorScheme.primary,
      colorScheme.primaryContainer,
      colorScheme.surfaceContainerHighest,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(height: _barGap),
          _BarRow(
            label: items[i].label,
            value: CurrencyFormatter.formatMinor(items[i].valueMinor, currency),
            fraction: maxValue > 0
                ? (items[i].valueMinor / maxValue).clamp(_minBarFraction, 1.0)
                : _minBarFraction,
            color: items[i].color ?? defaultColors[i % defaultColors.length],
            isHighlighted: items[i].isHighlighted || i == 0,
            theme: theme,
          ),
        ],
      ],
    );
  }
}

class _BarRow extends StatelessWidget {
  final String label;
  final String value;
  final double fraction;
  final Color color;
  final bool isHighlighted;
  final ThemeData theme;

  const _BarRow({
    required this.label,
    required this.value,
    required this.fraction,
    required this.color,
    required this.isHighlighted,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: isHighlighted
                    ? colorScheme.onSurface
                    : colorScheme.onSurfaceVariant,
                fontWeight: isHighlighted ? FontWeight.w500 : FontWeight.w400,
              ),
            ),
            Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        LayoutBuilder(
          builder: (context, constraints) {
            return Container(
              height: MultiComparisonBar._barHeight,
              width: constraints.maxWidth * fraction,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(MultiComparisonBar._borderRadius),
              ),
            );
          },
        ),
      ],
    );
  }
}
