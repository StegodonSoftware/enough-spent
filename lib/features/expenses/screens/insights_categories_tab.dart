import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../categories/category_controller.dart';
import '../../currency/data/currency_registry.dart';
import '../../currency/models/currency.dart';
import '../../settings/settings_controller.dart';
import '../expense_controller.dart';
import '../models/expense_totals.dart';
import '../widgets/insights/category_proportion_row.dart';
import '../widgets/insights/insight_card.dart';
import '../widgets/insights/segmented_category_bar.dart';

/// Time period for category insights.
enum InsightsPeriod {
  thisWeek('This Week'),
  thisMonth('This Month'),
  allTime('All Time');

  final String label;
  const InsightsPeriod(this.label);
}

/// Categories insights tab showing spending distribution by category.
class InsightsCategoriesTab extends StatefulWidget {
  const InsightsCategoriesTab({super.key});

  @override
  State<InsightsCategoriesTab> createState() => _InsightsCategoriesTabState();
}

class _InsightsCategoriesTabState extends State<InsightsCategoriesTab> {
  InsightsPeriod _selectedPeriod = InsightsPeriod.thisMonth;
  bool _showAllCategories = false;

  static const int _maxVisibleCategories = 5;

  @override
  Widget build(BuildContext context) {
    final expenseController = context.watch<ExpenseController>();
    final categoryController = context.watch<CategoryController>();
    final settingsController = context.read<SettingsController>();
    final currencyRegistry = context.read<CurrencyRegistry>();
    final appColors = context.appColors;

    final currency = currencyRegistry.getByCode(
      settingsController.primaryCurrency,
    );

    // Get category totals for selected period
    final categoryTotals = _getCategoryTotals(expenseController);
    final totalSpending = categoryTotals.fold(
      0,
      (sum, c) => sum + c.totalMinor,
    );

    // Build segments with colors
    final segments = _buildSegments(
      categoryTotals,
      totalSpending,
      categoryController,
      appColors,
    );
    final frequencySegments = _buildFrequencySegments(
      _getFrequencyTotals(expenseController),
      categoryController,
      appColors,
    );

    if (categoryTotals.isEmpty) {
      return _EmptyState(period: _selectedPeriod);
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Period selector
        _PeriodSelector(
          selected: _selectedPeriod,
          onChanged: (period) => setState(() => _selectedPeriod = period),
        ),
        const SizedBox(height: 16),

        // Spend distribution by category
        InsightCard(
          title: 'Where Your Money Goes',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SegmentedCategoryBar(segments: segments, height: 28),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: segments
                    .take(5)
                    .map((s) => _LegendItem(color: s.color, label: s.categoryName))
                    .toList(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Frequency distribution by category
        InsightCard(
          title: 'What You Frequently Buy',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SegmentedCategoryBar(segments: frequencySegments, height: 28),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: frequencySegments
                    .take(5)
                    .map((s) => _LegendItem(color: s.color, label: s.categoryName))
                    .toList(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Category breakdown list
        _BreakdownCard(
          title: 'Breakdown',
          segments: segments,
          currency: currency,
          appColors: appColors,
          showAll: _showAllCategories,
          maxVisible: _maxVisibleCategories,
          onToggleShowAll: segments.length > _maxVisibleCategories
              ? () => setState(() => _showAllCategories = !_showAllCategories)
              : null,
          itemLabel: 'categories',
        ),
      ],
    );
  }

  List<CategoryTotal> _getCategoryTotals(ExpenseController controller) {
    switch (_selectedPeriod) {
      case InsightsPeriod.thisWeek:
        return controller.categoryTotalsThisWeek;
      case InsightsPeriod.thisMonth:
        return controller.topCategoryTotalsThisMonth;
      case InsightsPeriod.allTime:
        return controller.categoryTotalsAllTime;
    }
  }

  List<CategoryTotal> _getFrequencyTotals(ExpenseController controller) {
    switch (_selectedPeriod) {
      case InsightsPeriod.thisWeek:
        return controller.categoryTotalsThisWeekByFrequency;
      case InsightsPeriod.thisMonth:
        return controller.categoryTotalsThisMonthByFrequency;
      case InsightsPeriod.allTime:
        return controller.categoryTotalsAllTimeByFrequency;
    }
  }

  List<CategorySegment> _buildSegments(
    List<CategoryTotal> totals,
    int totalSpending,
    CategoryController categoryController,
    AppColors appColors,
  ) {
    if (totals.isEmpty || totalSpending == 0) return [];

    return totals.map((ct) {
      final category = categoryController.get(ct.categoryId);
      final color = category?.color ?? appColors.uncategorizedBorder;
      final percentage = ct.totalMinor / totalSpending;

      return CategorySegment(
        categoryId: ct.categoryId,
        categoryName: ct.categoryName,
        totalMinor: ct.totalMinor,
        color: color,
        percentage: percentage,
      );
    }).toList();
  }

  List<CategorySegment> _buildFrequencySegments(
    List<CategoryTotal> totals,
    CategoryController categoryController,
    AppColors appColors,
  ) {
    final totalCount = totals.fold(0, (sum, c) => sum + c.count);
    if (totals.isEmpty || totalCount == 0) return [];

    return totals.map((ct) {
      final color = categoryController.get(ct.categoryId)?.color
          ?? appColors.uncategorizedBorder;
      return CategorySegment(
        categoryId: ct.categoryId,
        categoryName: ct.categoryName,
        totalMinor: ct.count, // repurposed: holds transaction count
        color: color,
        percentage: ct.count / totalCount,
      );
    }).toList();
  }
}

class _PeriodSelector extends StatelessWidget {
  final InsightsPeriod selected;
  final ValueChanged<InsightsPeriod> onChanged;

  const _PeriodSelector({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      children: InsightsPeriod.values.map((period) {
        final isSelected = period == selected;

        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: ChoiceChip(
            label: Text(period.label),
            selected: isSelected,
            onSelected: (_) => onChanged(period),
            selectedColor: colorScheme.primaryContainer,
            labelStyle: TextStyle(
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              color: isSelected
                  ? colorScheme.onPrimaryContainer
                  : colorScheme.onSurfaceVariant,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            side: BorderSide.none,
            showCheckmark: false,
          ),
        );
      }).toList(),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _BreakdownCard extends StatelessWidget {
  final String title;
  final List<CategorySegment> segments;
  final Currency currency;
  final AppColors appColors;
  final bool showAll;
  final int maxVisible;
  final VoidCallback? onToggleShowAll;
  final String itemLabel;

  const _BreakdownCard({
    required this.title,
    required this.segments,
    required this.currency,
    required this.appColors,
    required this.showAll,
    required this.maxVisible,
    required this.onToggleShowAll,
    required this.itemLabel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (segments.isEmpty) return const SizedBox.shrink();

    final hasMore = segments.length > maxVisible;
    final visibleSegments = showAll ? segments : segments.take(maxVisible);
    final hiddenCount = segments.length - maxVisible;

    return InsightCard(
      title: title,
      child: Column(
        children: [
          // Category/location rows
          for (final segment in visibleSegments)
            CategoryProportionRow(
              categoryName: segment.categoryName,
              color: segment.color,
              totalMinor: segment.totalMinor,
              percentage: segment.percentage,
              currency: currency,
            ),

          // "Other" summary row when collapsed and has more
          if (!showAll && hasMore) ...[
            Builder(
              builder: (context) {
                final otherSegments = segments.skip(maxVisible);
                final otherTotal = otherSegments.fold(
                  0,
                  (sum, s) => sum + s.totalMinor,
                );
                final otherPercentage = otherSegments.fold(
                  0.0,
                  (sum, s) => sum + s.percentage,
                );

                return CategoryProportionRow(
                  categoryName: 'Other ($hiddenCount $itemLabel)',
                  color: appColors.uncategorizedBorder,
                  totalMinor: otherTotal,
                  percentage: otherPercentage,
                  currency: currency,
                  isOther: true,
                );
              },
            ),
          ],

          // See All / Show Less button
          if (hasMore) ...[
            const SizedBox(height: 8),
            InkWell(
              onTap: onToggleShowAll,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      showAll ? 'Show Less' : 'See All ($hiddenCount more)',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      showAll
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      size: 20,
                      color: colorScheme.primary,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final InsightsPeriod period;

  const _EmptyState({required this.period});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    String message;
    switch (period) {
      case InsightsPeriod.thisWeek:
        message = 'No expenses this week';
      case InsightsPeriod.thisMonth:
        message = 'No expenses this month';
      case InsightsPeriod.allTime:
        message = 'No expenses yet';
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.pie_chart_outline,
              size: 64,
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: theme.textTheme.titleMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add expenses to see category breakdown',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
