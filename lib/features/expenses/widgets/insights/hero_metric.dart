import 'package:flutter/material.dart';

import '../../../currency/formatters/currency_formatter.dart';
import '../../../currency/models/currency.dart';

/// Large, prominent monetary display for key totals.
///
/// Displays a hero number with label and optional comparison text.
/// Used as the focal point of insight sections.
class HeroMetric extends StatelessWidget {
  final String label;
  final int valueMinor;
  final Currency currency;
  final String? comparisonText;

  /// Whether the comparison is positive (good), negative (bad), or neutral.
  /// - `true` = positive trend (e.g., spending decreased)
  /// - `false` = negative trend (e.g., spending increased)
  /// - `null` = neutral (no color tint)
  final bool? isPositive;

  const HeroMetric({
    super.key,
    required this.label,
    required this.valueMinor,
    required this.currency,
    this.comparisonText,
    this.isPositive,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Determine comparison text color based on trend
    Color? comparisonColor;
    if (isPositive == true) {
      comparisonColor = colorScheme.primary;
    } else if (isPositive == false) {
      comparisonColor = colorScheme.error;
    } else {
      comparisonColor = colorScheme.onSurfaceVariant;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            CurrencyFormatter.formatMinor(valueMinor, currency),
            style: theme.textTheme.displayMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurface,
            ),
          ),
        ),
        if (comparisonText != null) ...[
          const SizedBox(height: 4),
          Text(
            comparisonText!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: comparisonColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }
}
