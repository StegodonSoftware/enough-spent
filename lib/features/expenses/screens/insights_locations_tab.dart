import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../currency/data/currency_registry.dart';
import '../../currency/formatters/currency_formatter.dart';
import '../../currency/models/currency.dart';
import '../../settings/settings_controller.dart';
import '../expense_controller.dart';
import '../models/expense_totals.dart';
import '../widgets/insights/category_proportion_row.dart';
import '../widgets/insights/insight_card.dart';
import '../widgets/insights/segmented_category_bar.dart';

/// Time period for location insights.
enum LocationInsightsPeriod {
  thisWeek('This Week'),
  thisMonth('This Month'),
  allTime('All Time');

  final String label;
  const LocationInsightsPeriod(this.label);
}

/// Locations insights tab showing spending distribution by location.
class InsightsLocationsTab extends StatefulWidget {
  const InsightsLocationsTab({super.key});

  @override
  State<InsightsLocationsTab> createState() => _InsightsLocationsTabState();
}

class _InsightsLocationsTabState extends State<InsightsLocationsTab> {
  LocationInsightsPeriod _selectedPeriod = LocationInsightsPeriod.thisMonth;
  bool _showAllLocations = false;

  static const int _maxVisibleLocations = 5;

  @override
  Widget build(BuildContext context) {
    final expenseController = context.watch<ExpenseController>();
    final settingsController = context.read<SettingsController>();
    final currencyRegistry = context.read<CurrencyRegistry>();
    final appColors = context.appColors;

    final currency = currencyRegistry.getByCode(
      settingsController.primaryCurrency,
    );

    // Get location totals for selected period
    final locationTotals = _getLocationTotals(expenseController);
    final totalSpending = locationTotals.fold(
      0,
      (sum, l) => sum + l.totalMinor,
    );

    // Build segments with colors
    final amountSegments = _buildAmountSegments(
      locationTotals,
      totalSpending,
      appColors,
    );
    final frequencySegments = _buildFrequencySegments(
      _getFrequencyTotals(expenseController),
      appColors,
    );

    if (locationTotals.isEmpty) {
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

        // Top 3 by total spend
        _TopPlacesCard(
          title: 'Where You Spend Most',
          segments: amountSegments,
          metricBuilder: (s) =>
              CurrencyFormatter.formatMinor(s.totalMinor, currency),
        ),
        const SizedBox(height: 16),

        // Top 3 by visit frequency
        _TopPlacesCard(
          title: 'Places You Frequently Visit',
          segments: frequencySegments,
          metricBuilder: (s) =>
              '${s.totalMinor} ${s.totalMinor == 1 ? 'visit' : 'visits'}',
        ),
        const SizedBox(height: 16),

        // Location breakdown list
        _BreakdownCard(
          title: 'Breakdown',
          segments: amountSegments,
          currency: currency,
          appColors: appColors,
          showAll: _showAllLocations,
          maxVisible: _maxVisibleLocations,
          onToggleShowAll: amountSegments.length > _maxVisibleLocations
              ? () => setState(() => _showAllLocations = !_showAllLocations)
              : null,
          itemLabel: 'locations',
        ),
      ],
    );
  }

  List<LocationTotal> _getLocationTotals(ExpenseController controller) {
    switch (_selectedPeriod) {
      case LocationInsightsPeriod.thisWeek:
        return controller.locationTotalsThisWeek;
      case LocationInsightsPeriod.thisMonth:
        return controller.locationTotalsThisMonth;
      case LocationInsightsPeriod.allTime:
        return controller.locationTotalsAllTime;
    }
  }

  List<LocationTotal> _getFrequencyTotals(ExpenseController controller) {
    switch (_selectedPeriod) {
      case LocationInsightsPeriod.thisWeek:
        return controller.locationTotalsThisWeekByFrequency;
      case LocationInsightsPeriod.thisMonth:
        return controller.locationTotalsThisMonthByFrequency;
      case LocationInsightsPeriod.allTime:
        return controller.locationTotalsAllTimeByFrequency;
    }
  }

  List<CategorySegment> _buildAmountSegments(
    List<LocationTotal> totals,
    int totalSpending,
    AppColors appColors,
  ) {
    if (totals.isEmpty || totalSpending == 0) return [];

    return totals.asMap().entries.map((entry) {
      final index = entry.key;
      final lt = entry.value;
      final color = lt.locationId.isEmpty
          ? appColors.uncategorizedBorder
          : appColors.categoryColor(index);

      return CategorySegment(
        categoryId: lt.locationId,
        categoryName: lt.locationName,
        totalMinor: lt.totalMinor,
        color: color,
        percentage: lt.totalMinor / totalSpending,
      );
    }).toList();
  }

  List<CategorySegment> _buildFrequencySegments(
    List<LocationTotal> totals,
    AppColors appColors,
  ) {
    final totalCount = totals.fold(0, (sum, l) => sum + l.count);
    if (totals.isEmpty || totalCount == 0) return [];

    return totals.asMap().entries.map((entry) {
      final index = entry.key;
      final lt = entry.value;
      final color = lt.locationId.isEmpty
          ? appColors.uncategorizedBorder
          : appColors.categoryColor(index);

      return CategorySegment(
        categoryId: lt.locationId,
        categoryName: lt.locationName,
        totalMinor:
            lt.count, // repurposed: holds visit count for frequency display
        color: color,
        percentage: lt.count / totalCount,
      );
    }).toList();
  }
}

class _TopPlacesCard extends StatelessWidget {
  final String title;
  final List<CategorySegment> segments;
  final String Function(CategorySegment) metricBuilder;

  static const int _topCount = 3;

  const _TopPlacesCard({
    required this.title,
    required this.segments,
    required this.metricBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final topSegments = segments.take(_topCount).toList();
    final hasSecond = topSegments.length >= 2;
    final hasThird = topSegments.length >= 3;

    return InsightCard(
      title: title,
      elevated: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PlaceRow(
            rank: 1,
            segment: topSegments[0],
            metricText: metricBuilder(topSegments[0]),
          ),
          if (hasSecond) ...[
            const SizedBox(height: 4),
            _PlaceRow(
              rank: 2,
              segment: topSegments[1],
              metricText: metricBuilder(topSegments[1]),
            ),
          ],
          if (hasThird) ...[
            const SizedBox(height: 4),
            _PlaceRow(
              rank: 3,
              segment: topSegments[2],
              metricText: metricBuilder(topSegments[2]),
            ),
          ],
        ],
      ),
    );
  }
}

class _PlaceRow extends StatelessWidget {
  final int rank;
  final CategorySegment segment;
  final String metricText;

  static const double _badgeSizeRank1 = 36;
  static const double _badgeSizeRank2 = 28;
  static const double _badgeSizeRank3 = 22;
  static const double _nameGap = 8;

  const _PlaceRow({
    required this.rank,
    required this.segment,
    required this.metricText,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final percentText = '${(segment.percentage * 100).toStringAsFixed(1)}%';

    final isFirst = rank == 1;
    final isSecond = rank == 2;

    final badgeSize = isFirst
        ? _badgeSizeRank1
        : isSecond
        ? _badgeSizeRank2
        : _badgeSizeRank3;
    final badgeBg = isFirst
        ? colorScheme.primary
        : isSecond
        ? colorScheme.secondary
        : colorScheme.surfaceContainerHighest;
    final badgeFg = isFirst
        ? colorScheme.onPrimary
        : isSecond
        ? colorScheme.onSecondary
        : colorScheme.onSurfaceVariant;
    // Rank 1: circle; rank 2: circle; rank 3: rounded square
    final badgeRadius = rank == 3 ? 6.0 : badgeSize / 2;

    final nameStyle = isFirst
        ? theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)
        : isSecond
        ? theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600)
        : theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500);
    final amountStyle = isFirst
        ? theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: colorScheme.onSurface,
          )
        : isSecond
        ? theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
          )
        : theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w500,
            color: colorScheme.onSurfaceVariant,
          );

    final rowPadding = isFirst
        ? const EdgeInsets.symmetric(horizontal: 10, vertical: 8)
        : const EdgeInsets.symmetric(horizontal: 10, vertical: 5);

    final rowBg = isFirst
        ? colorScheme.primaryContainer.withValues(alpha: 0.35)
        : isSecond
        ? colorScheme.surfaceContainerHigh
        : null;

    return Container(
      decoration: rowBg != null
          ? BoxDecoration(color: rowBg, borderRadius: BorderRadius.circular(8))
          : null,
      padding: rowPadding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: badgeSize,
            height: badgeSize,
            decoration: BoxDecoration(
              color: badgeBg,
              borderRadius: BorderRadius.circular(badgeRadius),
            ),
            alignment: Alignment.center,
            child: Text(
              '$rank',
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: badgeFg,
                fontSize: isFirst
                    ? 16
                    : isSecond
                    ? 13
                    : null,
              ),
            ),
          ),
          const SizedBox(width: _nameGap),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  segment.categoryName,
                  style: nameStyle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text('$metricText ($percentText)', style: amountStyle),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PeriodSelector extends StatelessWidget {
  final LocationInsightsPeriod selected;
  final ValueChanged<LocationInsightsPeriod> onChanged;

  const _PeriodSelector({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      children: LocationInsightsPeriod.values.map((period) {
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
          // Location rows
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
  final LocationInsightsPeriod period;

  const _EmptyState({required this.period});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    String message;
    switch (period) {
      case LocationInsightsPeriod.thisWeek:
        message = 'No location data this week';
      case LocationInsightsPeriod.thisMonth:
        message = 'No location data this month';
      case LocationInsightsPeriod.allTime:
        message = 'No location data yet';
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.location_on_outlined,
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
              'Add locations to expenses to see breakdown',
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
