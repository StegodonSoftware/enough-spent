import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/widgets/empty_state.dart';
import '../../currency/data/currency_registry.dart';
import '../../currency/formatters/currency_formatter.dart';
import '../../currency/models/currency.dart';
import '../../settings/settings_controller.dart';
import '../expense_controller.dart';
import '../models/expense_totals.dart';
import '../widgets/insights/hero_metric.dart';
import '../widgets/insights/insight_card.dart';
import '../widgets/insights/mini_bar_chart.dart';
import '../widgets/insights/multi_comparison_bar.dart';

/// Spending insights tab showing time-based metrics and comparisons.
class InsightsSpendingTab extends StatelessWidget {
  const InsightsSpendingTab({super.key});

  @override
  Widget build(BuildContext context) {
    final expenseController = context.watch<ExpenseController>();
    final settingsController = context.read<SettingsController>();
    final currencyRegistry = context.read<CurrencyRegistry>();

    final currency = currencyRegistry.getByCode(
      settingsController.primaryCurrency,
    );

    if (expenseController.all.isEmpty) {
      return const EmptyState(
        icon: Icons.bar_chart_outlined,
        title: 'No expenses yet',
        subtitle: 'Add your first expense to see spending insights',
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Hero: Today and This Week
        _WeekHeroSection(
          totalToday: expenseController.totalToday,
          totalThisWeek: expenseController.totalThisWeek,
          todayComparison: expenseController.todayComparison,
          weekComparison: expenseController.thisWeekComparison,
          currency: currency,
        ),
        const SizedBox(height: 16),

        // Weekly comparison bars (3 bars)
        InsightCard(
          title: 'Weekly Comparison',
          child: MultiComparisonBar(
            items: [
              ComparisonItem(
                label: 'This Week',
                valueMinor: expenseController.totalThisWeek,
                isHighlighted: true,
              ),
              ComparisonItem(
                label: 'Last Week',
                valueMinor: expenseController.totalLastWeek,
              ),
              ComparisonItem(
                label: 'Weekly Average',
                valueMinor: expenseController.weeklyAverage,
              ),
            ],
            currency: currency,
          ),
        ),
        const SizedBox(height: 16),

        // Daily breakdown chart
        InsightCard(
          title: 'Last 7 Days',
          child: MiniBarChart(
            dailyTotals: expenseController.last7DayTotals,
            currency: currency,
          ),
        ),
        const SizedBox(height: 16),

        // Monthly section
        _MonthlySection(
          thisMonth: expenseController.totalThisMonth,
          lastMonth: expenseController.totalLastMonth,
          monthlyAverage: expenseController.monthlyAverage,
          thisMonthDailyAvg: expenseController.thisMonthDailyAverage,
          lastMonthDailyAvg: expenseController.lastMonthDailyAverage,
          monthComparison: expenseController.thisMonthDailyAvgComparison,
          currency: currency,
        ),
        const SizedBox(height: 16),

        // All-time summary
        _AllTimeSummary(
          total: expenseController.totalAllTime,
          dailyAverage: expenseController.dailyAverage,
          monthlyAverage: expenseController.monthlyAverage,
          firstExpenseDate: expenseController.firstExpenseDate,
          currency: currency,
        ),
      ],
    );
  }
}

class _WeekHeroSection extends StatelessWidget {
  final int totalToday;
  final int totalThisWeek;
  final SpendingComparison todayComparison;
  final SpendingComparison weekComparison;
  final Currency currency;

  const _WeekHeroSection({
    required this.totalToday,
    required this.totalThisWeek,
    required this.todayComparison,
    required this.weekComparison,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return InsightCard(
      elevated: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            // Today metric
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: HeroMetric(
                  label: 'Today',
                  valueMinor: totalToday,
                  currency: currency,
                  comparisonText: todayComparison.text,
                  isPositive: todayComparison.isPositive,
                ),
              ),
            ),
            const SizedBox(width: 12),
            // This Week metric
            Expanded(
              child: HeroMetric(
                label: 'This Week',
                valueMinor: totalThisWeek,
                currency: currency,
                comparisonText: weekComparison.text,
                isPositive: weekComparison.isPositive,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MonthlySection extends StatelessWidget {
  final int thisMonth;
  final int lastMonth;
  final int monthlyAverage;
  final int thisMonthDailyAvg;
  final int lastMonthDailyAvg;
  final SpendingComparison monthComparison;
  final Currency currency;

  const _MonthlySection({
    required this.thisMonth,
    required this.lastMonth,
    required this.monthlyAverage,
    required this.thisMonthDailyAvg,
    required this.lastMonthDailyAvg,
    required this.monthComparison,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InsightCard(
      title: 'Monthly',
      child: Column(
        children: [
          // This month hero
          HeroMetric(
            label: 'This Month',
            valueMinor: thisMonth,
            currency: currency,
            comparisonText: monthComparison.text,
            isPositive: monthComparison.isPositive,
          ),
          const SizedBox(height: 20),

          // Monthly comparison bars (3 bars)
          MultiComparisonBar(
            items: [
              ComparisonItem(
                label: 'This Month',
                valueMinor: thisMonth,
                isHighlighted: true,
              ),
              ComparisonItem(
                label: 'Last Month',
                valueMinor: lastMonth,
              ),
              ComparisonItem(
                label: 'Monthly Average',
                valueMinor: monthlyAverage,
              ),
            ],
            currency: currency,
          ),

          const SizedBox(height: 16),

          // Daily averages
          Row(
            children: [
              Expanded(
                child: _StatBox(
                  label: 'This Month Avg/Day',
                  value: CurrencyFormatter.formatMinor(thisMonthDailyAvg, currency),
                  theme: theme,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatBox(
                  label: 'Last Month Avg/Day',
                  value: CurrencyFormatter.formatMinor(lastMonthDailyAvg, currency),
                  theme: theme,
                  isSecondary: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  final String label;
  final String value;
  final ThemeData theme;
  final bool isSecondary;

  const _StatBox({
    required this.label,
    required this.value,
    required this.theme,
    this.isSecondary = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: isSecondary
                  ? colorScheme.onSurfaceVariant
                  : colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

class _AllTimeSummary extends StatelessWidget {
  final int total;
  final int dailyAverage;
  final int monthlyAverage;
  final DateTime? firstExpenseDate;
  final Currency currency;

  const _AllTimeSummary({
    required this.total,
    required this.dailyAverage,
    required this.monthlyAverage,
    required this.firstExpenseDate,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final formattedDate = firstExpenseDate != null
        ? DateFormat.yMMMMd().format(firstExpenseDate!)
        : 'N/A';

    return InsightCard(
      title: 'All Time',
      child: Column(
        children: [
          _SummaryRow(
            label: 'Total Spending',
            value: CurrencyFormatter.formatMinor(total, currency),
            isLarge: true,
            theme: theme,
          ),
          const SizedBox(height: 12),
          _SummaryRow(
            label: 'Daily Average',
            value: CurrencyFormatter.formatMinor(dailyAverage, currency),
            theme: theme,
          ),
          const SizedBox(height: 8),
          _SummaryRow(
            label: 'Monthly Average',
            value: CurrencyFormatter.formatMinor(monthlyAverage, currency),
            theme: theme,
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Tracking since',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                formattedDate,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final ThemeData theme;
  final bool isLarge;

  const _SummaryRow({
    required this.label,
    required this.value,
    required this.theme,
    this.isLarge = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: isLarge
              ? theme.textTheme.bodyLarge
              : theme.textTheme.bodyMedium,
        ),
        Text(
          value,
          style: isLarge
              ? theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                )
              : theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
        ),
      ],
    );
  }
}
