import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../currency/formatters/currency_formatter.dart';
import '../../../currency/models/currency.dart';
import '../../models/expense_totals.dart';

/// Simple horizontal bar chart for displaying daily totals.
///
/// Shows 7 days of data with day labels, proportional bars, and amounts.
/// Today's bar is highlighted with the primary color.
class MiniBarChart extends StatelessWidget {
  final List<DailyTotal> dailyTotals;
  final Currency currency;
  final Color? barColor;

  static const double _barHeight = 18.0;
  static const double _rowGap = 6.0;
  static const double _labelWidth = 48.0;
  static const double _borderRadius = 4.0;
  static const double _minBarFraction = 0.02;

  const MiniBarChart({
    super.key,
    required this.dailyTotals,
    required this.currency,
    this.barColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Find max value for proportional sizing
    final maxValue = dailyTotals.fold(0, (max, d) => d.totalMinor > max ? d.totalMinor : max);

    final today = DateUtils.dateOnly(DateTime.now());

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: dailyTotals.map((daily) {
        final isToday = DateUtils.dateOnly(daily.date) == today;
        final fraction = maxValue > 0
            ? (daily.totalMinor / maxValue).clamp(_minBarFraction, 1.0)
            : _minBarFraction;

        return Padding(
          padding: const EdgeInsets.only(bottom: _rowGap),
          child: _DayRow(
            label: _formatDayLabel(daily.date, today),
            value: CurrencyFormatter.formatMinor(daily.totalMinor, currency),
            fraction: fraction,
            isToday: isToday,
            barColor: barColor ?? colorScheme.primary,
            theme: theme,
          ),
        );
      }).toList(),
    );
  }

  String _formatDayLabel(DateTime date, DateTime today) {
    final dateOnly = DateUtils.dateOnly(date);
    final yesterday = today.subtract(const Duration(days: 1));

    if (dateOnly == today) {
      return 'Today';
    } else if (dateOnly == yesterday) {
      return 'Yest';
    } else {
      return DateFormat('E').format(date);
    }
  }
}

class _DayRow extends StatelessWidget {
  final String label;
  final String value;
  final double fraction;
  final bool isToday;
  final Color barColor;
  final ThemeData theme;

  const _DayRow({
    required this.label,
    required this.value,
    required this.fraction,
    required this.isToday,
    required this.barColor,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = theme.colorScheme;

    return Row(
      children: [
        SizedBox(
          width: MiniBarChart._labelWidth,
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: isToday ? colorScheme.primary : colorScheme.onSurfaceVariant,
              fontWeight: isToday ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
        Flexible(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  height: MiniBarChart._barHeight,
                  width: constraints.maxWidth * fraction,
                  decoration: BoxDecoration(
                    color: isToday ? barColor : colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(MiniBarChart._borderRadius),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          textAlign: TextAlign.right,
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w500,
            color: colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}
