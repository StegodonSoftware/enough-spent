import 'package:flutter/material.dart';

import '../../../currency/formatters/currency_formatter.dart';
import '../../../currency/models/currency.dart';

/// Visual comparison of two values using proportional horizontal bars.
///
/// Displays two stacked bars where width is proportional to value,
/// with labels and formatted amounts.
class ComparisonBar extends StatelessWidget {
  final String label1;
  final int value1Minor;
  final String label2;
  final int value2Minor;
  final Currency currency;
  final Color? color1;
  final Color? color2;

  static const double _barHeight = 24.0;
  static const double _barGap = 8.0;
  static const double _borderRadius = 6.0;
  static const double _minBarFraction = 0.05;

  const ComparisonBar({
    super.key,
    required this.label1,
    required this.value1Minor,
    required this.label2,
    required this.value2Minor,
    required this.currency,
    this.color1,
    this.color2,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final primaryColor = color1 ?? colorScheme.primary;
    final secondaryColor = color2 ?? colorScheme.surfaceContainerHighest;

    // Calculate proportions
    final maxValue = value1Minor > value2Minor ? value1Minor : value2Minor;
    final fraction1 =
        maxValue > 0 ? (value1Minor / maxValue).clamp(_minBarFraction, 1.0) : _minBarFraction;
    final fraction2 =
        maxValue > 0 ? (value2Minor / maxValue).clamp(_minBarFraction, 1.0) : _minBarFraction;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _BarRow(
          label: label1,
          value: CurrencyFormatter.formatMinor(value1Minor, currency),
          fraction: fraction1,
          color: primaryColor,
          theme: theme,
        ),
        const SizedBox(height: _barGap),
        _BarRow(
          label: label2,
          value: CurrencyFormatter.formatMinor(value2Minor, currency),
          fraction: fraction2,
          color: secondaryColor,
          theme: theme,
          isSecondary: true,
        ),
      ],
    );
  }
}

class _BarRow extends StatelessWidget {
  final String label;
  final String value;
  final double fraction;
  final Color color;
  final ThemeData theme;
  final bool isSecondary;

  const _BarRow({
    required this.label,
    required this.value,
    required this.fraction,
    required this.color,
    required this.theme,
    this.isSecondary = false,
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
                color: isSecondary
                    ? colorScheme.onSurfaceVariant
                    : colorScheme.onSurface,
                fontWeight: isSecondary ? FontWeight.w400 : FontWeight.w500,
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
              height: ComparisonBar._barHeight,
              width: constraints.maxWidth * fraction,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(ComparisonBar._borderRadius),
              ),
            );
          },
        ),
      ],
    );
  }
}
