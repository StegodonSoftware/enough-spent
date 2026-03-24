import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/currency/currency_service.dart';
import '../../currency/data/currency_registry.dart';
import '../../currency/formatters/currency_formatter.dart';
import '../../settings/settings_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/toast/toast.dart';
import '../../../core/widgets/empty_state.dart';
import '../../categories/category_controller.dart';
import '../../locations/location_controller.dart';
import '../expense_controller.dart';
import '../models/expense.dart';
import '../widgets/expense_tile.dart';
import 'edit_transaction_screen.dart';

/// Preset date ranges for quick filtering.
enum DatePreset {
  today('Today'),
  thisWeek('This Week'),
  thisMonth('This Month'),
  last30Days('Last 30 Days'),
  custom('Custom');

  final String label;
  const DatePreset(this.label);
}

/// Filter state for transactions - local to this tab, resets on navigation.
class _TransactionFilter {
  final DatePreset? datePreset;
  final DateTimeRange? customDateRange;
  final int? minAmountMinor;
  final int? maxAmountMinor;
  final Set<String> selectedCategoryIds;
  final Set<String> selectedLocationIds;

  const _TransactionFilter({
    this.datePreset,
    this.customDateRange,
    this.minAmountMinor,
    this.maxAmountMinor,
    this.selectedCategoryIds = const {},
    this.selectedLocationIds = const {},
  });

  bool get hasActiveFilters =>
      datePreset != null ||
      minAmountMinor != null ||
      maxAmountMinor != null ||
      selectedCategoryIds.isNotEmpty ||
      selectedLocationIds.isNotEmpty;

  int get activeFilterCount {
    int count = 0;
    if (datePreset != null) count++;
    if (minAmountMinor != null || maxAmountMinor != null) count++;
    if (selectedCategoryIds.isNotEmpty) count++;
    if (selectedLocationIds.isNotEmpty) count++;
    return count;
  }

  _TransactionFilter copyWith({
    DatePreset? datePreset,
    bool clearDatePreset = false,
    DateTimeRange? customDateRange,
    bool clearCustomDateRange = false,
    int? minAmountMinor,
    bool clearMinAmount = false,
    int? maxAmountMinor,
    bool clearMaxAmount = false,
    Set<String>? selectedCategoryIds,
    Set<String>? selectedLocationIds,
  }) {
    return _TransactionFilter(
      datePreset: clearDatePreset ? null : (datePreset ?? this.datePreset),
      customDateRange: clearCustomDateRange
          ? null
          : (customDateRange ?? this.customDateRange),
      minAmountMinor:
          clearMinAmount ? null : (minAmountMinor ?? this.minAmountMinor),
      maxAmountMinor:
          clearMaxAmount ? null : (maxAmountMinor ?? this.maxAmountMinor),
      selectedCategoryIds: selectedCategoryIds ?? this.selectedCategoryIds,
      selectedLocationIds: selectedLocationIds ?? this.selectedLocationIds,
    );
  }

  static const empty = _TransactionFilter();
}

class TransactionsFilterTab extends StatefulWidget {
  const TransactionsFilterTab({super.key});

  @override
  State<TransactionsFilterTab> createState() => _TransactionsFilterTabState();
}

class _TransactionsFilterTabState extends State<TransactionsFilterTab> {
  static const int _pageSize = 30;
  static const double _loadMoreThreshold = 200.0;

  _TransactionFilter _filter = _TransactionFilter.empty;
  int _visibleCount = _pageSize;

  final _minAmountController = TextEditingController();
  final _maxAmountController = TextEditingController();
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _minAmountController.dispose();
    _maxAmountController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;

    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;

    if (maxScroll - currentScroll <= _loadMoreThreshold) {
      _loadMore();
    }
  }

  void _loadMore() {
    final expenseController = context.read<ExpenseController>();
    final filteredCount = _applyFilters(expenseController.all).length;

    if (_visibleCount < filteredCount) {
      setState(() {
        _visibleCount = (_visibleCount + _pageSize).clamp(0, filteredCount);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final expenseController = context.watch<ExpenseController>();
    final allExpenses = expenseController.all;

    if (allExpenses.isEmpty) {
      return const EmptyState(
        icon: Icons.filter_list_off,
        title: 'No transactions to filter',
        subtitle: 'Add some expenses first to use filters',
      );
    }

    final filteredExpenses = _applyFilters(allExpenses);

    // Compute total in primary currency
    final settings = context.read<SettingsController>();
    final currencyService = context.read<CurrencyService>();
    final currencyRegistry = context.read<CurrencyRegistry>();
    final primaryCode = settings.primaryCurrency;
    final primaryCurrency = currencyRegistry.getByCode(primaryCode);

    var totalMinor = 0;
    for (final expense in filteredExpenses) {
      if (expense.primaryCurrencyCode == primaryCode &&
          expense.amountInPrimary != null) {
        totalMinor += expense.amountInPrimary!;
      } else if (expense.currencyCode == primaryCode) {
        totalMinor += expense.amountMinor;
      } else {
        totalMinor +=
            currencyService.convert(
              amountMinor: expense.amountMinor,
              from: expense.currencyCode,
              to: primaryCode,
            ) ??
            0;
      }
    }

    final formattedTotal = CurrencyFormatter.formatMinor(
      totalMinor,
      primaryCurrency,
    );

    return Column(
      children: [
        // Prominent results header with filter button
        _ResultsHeader(
          totalCount: allExpenses.length,
          filteredCount: filteredExpenses.length,
          formattedTotal: formattedTotal,
          hasFilters: _filter.hasActiveFilters,
          activeFilterCount: _filter.activeFilterCount,
          onOpenFilters: () => _showFilterSheet(context),
          onClearFilters: _clearAllFilters,
        ),

        // Active filter chips (if any)
        if (_filter.hasActiveFilters)
          _ActiveFilterChips(
            filter: _filter,
            onFilterChanged: _updateFilter,
          ),

        // Results list (paginated)
        Expanded(
          child: filteredExpenses.isEmpty
              ? const _NoMatchesState()
              : _FilteredExpenseList(
                  expenses: filteredExpenses.take(_visibleCount).toList(),
                  scrollController: _scrollController,
                  canLoadMore: _visibleCount < filteredExpenses.length,
                ),
        ),
      ],
    );
  }

  void _showFilterSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => _FilterBottomSheet(
        initialFilter: _filter,
        minAmountController: _minAmountController,
        maxAmountController: _maxAmountController,
        onFilterChanged: _updateFilter,
        onClearAll: _clearAllFilters,
      ),
    );
  }

  void _clearAllFilters() {
    _minAmountController.clear();
    _maxAmountController.clear();
    setState(() {
      _filter = _TransactionFilter.empty;
      _visibleCount = _pageSize;
    });
  }

  void _updateFilter(_TransactionFilter newFilter) {
    setState(() {
      _filter = newFilter;
      _visibleCount = _pageSize; // Reset pagination when filter changes
    });
  }

  List<Expense> _applyFilters(List<Expense> expenses) {
    var result = expenses;

    // Date filter
    if (_filter.datePreset != null) {
      final dateRange = _getDateRangeForPreset(_filter.datePreset!);
      if (dateRange != null) {
        result = result.where((e) {
          final date = DateUtils.dateOnly(e.date);
          return !date.isBefore(dateRange.start) &&
              !date.isAfter(dateRange.end);
        }).toList();
      }
    }

    // Amount filter
    // Use amountInPrimary for comparison if available (multi-currency expenses),
    // otherwise use amountMinor (single-currency or legacy expenses)
    if (_filter.minAmountMinor != null) {
      result = result.where((e) {
        final amount = e.hasPrimaryConversion ? e.amountInPrimary! : e.amountMinor;
        return amount >= _filter.minAmountMinor!;
      }).toList();
    }
    if (_filter.maxAmountMinor != null) {
      result = result.where((e) {
        final amount = e.hasPrimaryConversion ? e.amountInPrimary! : e.amountMinor;
        return amount <= _filter.maxAmountMinor!;
      }).toList();
    }

    // Category filter (OR logic - matches any selected)
    if (_filter.selectedCategoryIds.isNotEmpty) {
      result = result
          .where((e) => _filter.selectedCategoryIds.contains(e.categoryId))
          .toList();
    }

    // Location filter (OR logic - matches any selected)
    if (_filter.selectedLocationIds.isNotEmpty) {
      result = result
          .where((e) => _filter.selectedLocationIds.contains(e.locationId))
          .toList();
    }

    return result;
  }

  DateTimeRange? _getDateRangeForPreset(DatePreset preset) {
    final now = DateTime.now();
    final today = DateUtils.dateOnly(now);

    switch (preset) {
      case DatePreset.today:
        return DateTimeRange(start: today, end: today);

      case DatePreset.thisWeek:
        final startOfWeek = today.subtract(Duration(days: today.weekday - 1));
        return DateTimeRange(start: startOfWeek, end: today);

      case DatePreset.thisMonth:
        final startOfMonth = DateTime(now.year, now.month);
        return DateTimeRange(start: startOfMonth, end: today);

      case DatePreset.last30Days:
        final start = today.subtract(const Duration(days: 29));
        return DateTimeRange(start: start, end: today);

      case DatePreset.custom:
        return _filter.customDateRange;
    }
  }
}

/// Date filter with preset chips and custom range picker.
class _DateFilterSection extends StatelessWidget {
  final DatePreset? selectedPreset;
  final DateTimeRange? customRange;
  final ValueChanged<DatePreset?> onPresetSelected;
  final ValueChanged<DateTimeRange> onCustomRangeSelected;

  const _DateFilterSection({
    required this.selectedPreset,
    required this.customRange,
    required this.onPresetSelected,
    required this.onCustomRangeSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Date',
          style: theme.textTheme.labelMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),

        // Preset chips with custom styling
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final preset
                  in DatePreset.values.where((p) => p != DatePreset.custom))
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _DatePresetChip(
                    label: preset.label,
                    isSelected: selectedPreset == preset,
                    onTap: () => onPresetSelected(
                      selectedPreset == preset ? null : preset,
                    ),
                  ),
                ),
              // Custom date range chip
              _DatePresetChip(
                label: selectedPreset == DatePreset.custom && customRange != null
                    ? _formatDateRange(customRange!)
                    : 'Custom',
                icon: Icons.calendar_today,
                isSelected: selectedPreset == DatePreset.custom,
                onTap: () => _showDateRangePicker(context),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatDateRange(DateTimeRange range) {
    final startFmt = DateFormat.MMMd().format(range.start);
    final endFmt = DateFormat.MMMd().format(range.end);
    return '$startFmt - $endFmt';
  }

  Future<void> _showDateRangePicker(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: now,
      initialDateRange: customRange ??
          DateTimeRange(
            start: now.subtract(const Duration(days: 7)),
            end: now,
          ),
    );

    if (picked != null) {
      onCustomRangeSelected(picked);
    }
  }
}

/// Styled date preset chip with outlined/filled states.
class _DatePresetChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _DatePresetChip({
    required this.label,
    this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          // Unselected: light primary tint; Selected: filled primaryContainer
          color: isSelected
              ? colorScheme.primaryContainer
              : colorScheme.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? colorScheme.primary
                : colorScheme.primary.withValues(alpha: 0.4),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: theme.textTheme.labelLarge?.copyWith(
                color: isSelected
                    ? colorScheme.onPrimaryContainer
                    : colorScheme.primary,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
            if (icon != null) ...[
              const SizedBox(width: 4),
              Icon(
                icon,
                size: 16,
                color: isSelected
                    ? colorScheme.onPrimaryContainer
                    : colorScheme.primary,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Amount range filter with min/max inputs.
class _AmountFilterSection extends StatelessWidget {
  final TextEditingController minController;
  final TextEditingController maxController;
  final ValueChanged<int?> onMinChanged;
  final ValueChanged<int?> onMaxChanged;

  const _AmountFilterSection({
    required this.minController,
    required this.maxController,
    required this.onMinChanged,
    required this.onMaxChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final settingsController = context.read<SettingsController>();
    final currencyRegistry = context.read<CurrencyRegistry>();
    final currency =
        currencyRegistry.getByCode(settingsController.primaryCurrency);

    // Cross-validate min/max
    final minValue = double.tryParse(minController.text);
    final maxValue = double.tryParse(maxController.text);
    final hasRangeError = minValue != null && maxValue != null && minValue > maxValue;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Amount',
          style: theme.textTheme.labelMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: minController,
                decoration: InputDecoration(
                  labelText: 'Min',
                  prefixText: currency.symbol,
                  isDense: true,
                  border: const OutlineInputBorder(),
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                ],
                onChanged: (value) {
                  if (value.isEmpty) {
                    onMinChanged(null);
                  } else {
                    final parsed = double.tryParse(value);
                    if (parsed != null) {
                      onMinChanged((parsed * currency.numToBasic).round());
                    }
                  }
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                '–',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            Expanded(
              child: TextField(
                controller: maxController,
                decoration: InputDecoration(
                  labelText: 'Max',
                  prefixText: currency.symbol,
                  isDense: true,
                  border: const OutlineInputBorder(),
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                ],
                onChanged: (value) {
                  if (value.isEmpty) {
                    onMaxChanged(null);
                  } else {
                    final parsed = double.tryParse(value);
                    if (parsed != null) {
                      onMaxChanged((parsed * currency.numToBasic).round());
                    }
                  }
                },
              ),
            ),
          ],
        ),
        if (hasRangeError)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Minimum must be less than maximum',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.error,
              ),
            ),
          ),
      ],
    );
  }
}

/// Prominent header showing results count with filter button.
class _ResultsHeader extends StatelessWidget {
  final int totalCount;
  final int filteredCount;
  final String formattedTotal;
  final bool hasFilters;
  final int activeFilterCount;
  final VoidCallback onOpenFilters;
  final VoidCallback onClearFilters;

  const _ResultsHeader({
    required this.totalCount,
    required this.filteredCount,
    required this.formattedTotal,
    required this.hasFilters,
    required this.activeFilterCount,
    required this.onOpenFilters,
    required this.onClearFilters,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
      ),
      child: Row(
        children: [
          // Total amount as hero, count in subtitle
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  formattedTotal,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: colorScheme.onSurface,
                  ),
                ),
                Text(
                  hasFilters
                      ? '$filteredCount of $totalCount transactions'
                      : '$totalCount transactions',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),

          // Clear filters button (if active)
          if (hasFilters)
            TextButton(
              onPressed: onClearFilters,
              child: const Text('Clear'),
            ),

          // Filter button with badge
          _FilterButton(
            activeCount: activeFilterCount,
            onTap: onOpenFilters,
          ),
        ],
      ),
    );
  }
}

/// Filter button with icon and label for better discoverability.
class _FilterButton extends StatelessWidget {
  final int activeCount;
  final VoidCallback onTap;

  const _FilterButton({
    required this.activeCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final hasActive = activeCount > 0;

    return FilledButton.tonal(
      onPressed: onTap,
      style: FilledButton.styleFrom(
        backgroundColor: hasActive
            ? colorScheme.primaryContainer
            : colorScheme.surfaceContainerHighest,
        foregroundColor: hasActive
            ? colorScheme.onPrimaryContainer
            : colorScheme.onSurfaceVariant,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.tune, size: 18),
          const SizedBox(width: 8),
          Text(
            hasActive ? 'Filters ($activeCount)' : 'Filters',
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: hasActive ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// Row of dismissible chips showing active filters.
class _ActiveFilterChips extends StatelessWidget {
  final _TransactionFilter filter;
  final ValueChanged<_TransactionFilter> onFilterChanged;

  const _ActiveFilterChips({
    required this.filter,
    required this.onFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    final categoryController = context.watch<CategoryController>();

    final chips = <Widget>[];

    // Date filter chip
    if (filter.datePreset != null) {
      String label;
      if (filter.datePreset == DatePreset.custom && filter.customDateRange != null) {
        final range = filter.customDateRange!;
        final startFmt = DateFormat.MMMd().format(range.start);
        final endFmt = DateFormat.MMMd().format(range.end);
        label = '$startFmt - $endFmt';
      } else {
        label = filter.datePreset!.label;
      }
      chips.add(_FilterChip(
        label: label,
        icon: Icons.calendar_today,
        onRemove: () => onFilterChanged(filter.copyWith(
          clearDatePreset: true,
          clearCustomDateRange: true,
        )),
      ));
    }

    // Amount filter chip
    if (filter.minAmountMinor != null || filter.maxAmountMinor != null) {
      chips.add(_FilterChip(
        label: 'Amount range',
        icon: Icons.attach_money,
        onRemove: () => onFilterChanged(filter.copyWith(
          clearMinAmount: true,
          clearMaxAmount: true,
        )),
      ));
    }

    // Category filter chip
    if (filter.selectedCategoryIds.isNotEmpty) {
      final count = filter.selectedCategoryIds.length;
      final label = count == 1
          ? _getCategoryName(filter.selectedCategoryIds.first, categoryController)
          : '$count categories';
      chips.add(_FilterChip(
        label: label,
        icon: Icons.category_outlined,
        onRemove: () => onFilterChanged(filter.copyWith(
          selectedCategoryIds: {},
        )),
      ));
    }

    // Location filter chip
    if (filter.selectedLocationIds.isNotEmpty) {
      final count = filter.selectedLocationIds.length;
      chips.add(_FilterChip(
        label: count == 1 ? '1 location' : '$count locations',
        icon: Icons.location_on_outlined,
        onRemove: () => onFilterChanged(filter.copyWith(
          selectedLocationIds: {},
        )),
      ));
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: chips
              .map((chip) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: chip,
                  ))
              .toList(),
        ),
      ),
    );
  }

  String _getCategoryName(String id, CategoryController controller) {
    if (id.isEmpty) return 'Uncategorized';
    return controller.get(id)?.name ?? 'Unknown';
  }
}

/// Individual filter chip with remove button.
class _FilterChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onRemove;

  const _FilterChip({
    required this.label,
    required this.icon,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.only(left: 10, right: 4),
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: colorScheme.onSecondaryContainer,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: colorScheme.onSecondaryContainer,
            ),
          ),
          SizedBox(
            width: 28,
            height: 28,
            child: IconButton(
              padding: EdgeInsets.zero,
              iconSize: 16,
              onPressed: onRemove,
              icon: Icon(
                Icons.close,
                color: colorScheme.onSecondaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Bottom sheet containing all filter options.
///
/// Maintains its own filter state to allow multiple filters to be combined
/// without stale state issues.
class _FilterBottomSheet extends StatefulWidget {
  final _TransactionFilter initialFilter;
  final TextEditingController minAmountController;
  final TextEditingController maxAmountController;
  final ValueChanged<_TransactionFilter> onFilterChanged;
  final VoidCallback onClearAll;

  const _FilterBottomSheet({
    required this.initialFilter,
    required this.minAmountController,
    required this.maxAmountController,
    required this.onFilterChanged,
    required this.onClearAll,
  });

  @override
  State<_FilterBottomSheet> createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends State<_FilterBottomSheet> {
  late _TransactionFilter _filter;
  final _sheetController = DraggableScrollableController();
  bool _expandedForKeyboard = false;

  @override
  void initState() {
    super.initState();
    _filter = widget.initialFilter;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    if (bottomInset > 0 && !_expandedForKeyboard) {
      _expandedForKeyboard = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _sheetController.isAttached) {
          _sheetController.animateTo(
            1.0,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      });
    } else if (bottomInset == 0) {
      _expandedForKeyboard = false;
    }
  }

  @override
  void dispose() {
    _sheetController.dispose();
    super.dispose();
  }

  void _updateFilter(_TransactionFilter newFilter) {
    setState(() => _filter = newFilter);
    widget.onFilterChanged(newFilter);
  }

  void _clearAll() {
    widget.onClearAll();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return DraggableScrollableSheet(
      controller: _sheetController,
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 1.0,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            children: [
              // Handle bar
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Container(
                  width: 32,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 8, 8),
                child: Row(
                  children: [
                    Text(
                      'Filters',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (_filter.hasActiveFilters) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${_filter.activeFilterCount}',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                    const Spacer(),
                    if (_filter.hasActiveFilters)
                      TextButton(
                        onPressed: _clearAll,
                        child: const Text('Clear all'),
                      ),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Done'),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1),

              // Filter sections
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Date filter
                    _DateFilterSection(
                      selectedPreset: _filter.datePreset,
                      customRange: _filter.customDateRange,
                      onPresetSelected: (preset) => _updateFilter(
                        _filter.copyWith(
                          datePreset: preset,
                          clearDatePreset: preset == null,
                        ),
                      ),
                      onCustomRangeSelected: (range) => _updateFilter(
                        _filter.copyWith(
                          datePreset: DatePreset.custom,
                          customDateRange: range,
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Amount filter
                    _AmountFilterSection(
                      minController: widget.minAmountController,
                      maxController: widget.maxAmountController,
                      onMinChanged: (value) => _updateFilter(
                        _filter.copyWith(
                          minAmountMinor: value,
                          clearMinAmount: value == null,
                        ),
                      ),
                      onMaxChanged: (value) => _updateFilter(
                        _filter.copyWith(
                          maxAmountMinor: value,
                          clearMaxAmount: value == null,
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Category filter (inline)
                    _InlineCategoryFilter(
                      selectedIds: _filter.selectedCategoryIds,
                      onSelectionChanged: (ids) => _updateFilter(
                        _filter.copyWith(selectedCategoryIds: ids),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Location filter (inline)
                    _InlineLocationFilter(
                      selectedIds: _filter.selectedLocationIds,
                      onSelectionChanged: (ids) => _updateFilter(
                        _filter.copyWith(selectedLocationIds: ids),
                      ),
                    ),

                    // Bottom padding for safe area
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Empty state when filters produce no matches.
class _NoMatchesState extends StatelessWidget {
  const _NoMatchesState();

  @override
  Widget build(BuildContext context) {
    return const EmptyState(
      icon: Icons.search_off,
      title: 'No matching transactions',
      subtitle: 'Try adjusting your filters to see more results',
    );
  }
}

/// Multi-select category filter with autocomplete search.
class _InlineCategoryFilter extends StatefulWidget {
  final Set<String> selectedIds;
  final ValueChanged<Set<String>> onSelectionChanged;

  const _InlineCategoryFilter({
    required this.selectedIds,
    required this.onSelectionChanged,
  });

  @override
  State<_InlineCategoryFilter> createState() => _InlineCategoryFilterState();
}

class _InlineCategoryFilterState extends State<_InlineCategoryFilter> {
  final _textController = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _addCategory(String id) {
    final newSet = Set<String>.from(widget.selectedIds)..add(id);
    widget.onSelectionChanged(newSet);
    _textController.clear();
  }

  void _removeCategory(String id) {
    final newSet = Set<String>.from(widget.selectedIds)..remove(id);
    widget.onSelectionChanged(newSet);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final appColors = context.appColors;
    final categoryController = context.watch<CategoryController>();
    final categories = categoryController.all;

    // Build list of selected category info for display
    final selectedCategories = widget.selectedIds.map((id) {
      if (id.isEmpty) {
        return (id: '', name: 'Uncategorized', color: appColors.uncategorizedBorder);
      }
      final cat = categoryController.get(id);
      return (
        id: id,
        name: cat?.name ?? 'Unknown',
        color: cat?.isActive == true ? cat!.color : appColors.inactiveCategoryFill,
      );
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          children: [
            Icon(
              Icons.category_outlined,
              size: 18,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Text(
              'Categories',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            if (widget.selectedIds.isNotEmpty) ...[
              const Spacer(),
              TextButton(
                onPressed: () => widget.onSelectionChanged({}),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'Clear',
                  style: theme.textTheme.labelSmall,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),

        // Selected categories as removable chips
        if (selectedCategories.isNotEmpty) ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: selectedCategories.map((cat) {
              return _RemovableFilterChip(
                label: cat.name,
                color: cat.color,
                onRemove: () => _removeCategory(cat.id),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
        ],

        // Autocomplete search field
        Autocomplete<({String id, String name, Color color})>(
          textEditingController: _textController,
          focusNode: _focusNode,
          optionsViewOpenDirection: OptionsViewOpenDirection.up,
          optionsBuilder: (textEditingValue) {
            final query = textEditingValue.text.trim().toLowerCase();

            // Build options list excluding already selected
            final options = <({String id, String name, Color color})>[];

            // Add uncategorized option if not selected
            if (!widget.selectedIds.contains('')) {
              if (query.isEmpty || 'uncategorized'.contains(query)) {
                options.add((
                  id: '',
                  name: 'Uncategorized',
                  color: appColors.uncategorizedBorder,
                ));
              }
            }

            // Add category options
            for (final cat in categories) {
              if (!widget.selectedIds.contains(cat.id)) {
                if (query.isEmpty || cat.name.toLowerCase().contains(query)) {
                  options.add((
                    id: cat.id,
                    name: cat.name,
                    color: cat.isActive ? cat.color : appColors.inactiveCategoryFill,
                  ));
                }
              }
            }

            return options;
          },
          displayStringForOption: (option) => option.name,
          onSelected: (option) => _addCategory(option.id),
          optionsViewBuilder: (context, onSelected, options) {
            return _CategoryOptionsDropdown(
              options: options.toList(),
              onSelected: onSelected,
            );
          },
          fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
            return TextField(
              controller: controller,
              focusNode: focusNode,
              decoration: InputDecoration(
                hintText: 'Search categories to add...',
                border: const OutlineInputBorder(),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                prefixIcon: const Icon(Icons.search, size: 20),
              ),
              textCapitalization: TextCapitalization.words,
            );
          },
        ),
      ],
    );
  }
}

/// Multi-select location filter with autocomplete search.
class _InlineLocationFilter extends StatefulWidget {
  final Set<String> selectedIds;
  final ValueChanged<Set<String>> onSelectionChanged;

  const _InlineLocationFilter({
    required this.selectedIds,
    required this.onSelectionChanged,
  });

  @override
  State<_InlineLocationFilter> createState() => _InlineLocationFilterState();
}

class _InlineLocationFilterState extends State<_InlineLocationFilter> {
  final _textController = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _addLocation(String id) {
    final newSet = Set<String>.from(widget.selectedIds)..add(id);
    widget.onSelectionChanged(newSet);
    _textController.clear();
  }

  void _removeLocation(String id) {
    final newSet = Set<String>.from(widget.selectedIds)..remove(id);
    widget.onSelectionChanged(newSet);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final expenseController = context.watch<ExpenseController>();
    final locationController = context.watch<LocationController>();
    // Get locations that have expenses
    final locationIds = expenseController.expensesByLocation.keys.toList();

    // Build list of selected location info for display
    final selectedLocations = widget.selectedIds.map((id) {
      final loc = locationController.get(id);
      return (id: id, name: loc?.name ?? 'Unknown');
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          children: [
            Icon(
              Icons.location_on_outlined,
              size: 18,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Text(
              'Locations',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            if (widget.selectedIds.isNotEmpty) ...[
              const Spacer(),
              TextButton(
                onPressed: () => widget.onSelectionChanged({}),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'Clear',
                  style: theme.textTheme.labelSmall,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),

        // Selected locations as removable chips
        if (selectedLocations.isNotEmpty) ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: selectedLocations.map((loc) {
              return _RemovableFilterChip(
                label: loc.name,
                color: colorScheme.secondaryContainer,
                onRemove: () => _removeLocation(loc.id),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
        ],

        // Autocomplete search field or empty state
        if (locationIds.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'No locations available',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          )
        else
          Autocomplete<({String id, String name})>(
            textEditingController: _textController,
            focusNode: _focusNode,
            optionsViewOpenDirection: OptionsViewOpenDirection.up,
            optionsBuilder: (textEditingValue) {
              final query = textEditingValue.text.trim().toLowerCase();

              // Build options list excluding already selected
              final options = <({String id, String name})>[];

              for (final locId in locationIds) {
                if (!widget.selectedIds.contains(locId)) {
                  final loc = locationController.get(locId);
                  final name = loc?.name ?? 'Unknown';
                  if (query.isEmpty || name.toLowerCase().contains(query)) {
                    options.add((id: locId, name: name));
                  }
                }
              }

              return options;
            },
            displayStringForOption: (option) => option.name,
            onSelected: (option) => _addLocation(option.id),
            optionsViewBuilder: (context, onSelected, options) {
              return _LocationOptionsDropdown(
                options: options.toList(),
                onSelected: onSelected,
              );
            },
            fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
              return TextField(
                controller: controller,
                focusNode: focusNode,
                decoration: InputDecoration(
                  hintText: 'Search locations to add...',
                  border: const OutlineInputBorder(),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  prefixIcon: const Icon(Icons.search, size: 20),
                ),
                textCapitalization: TextCapitalization.words,
              );
            },
          ),
      ],
    );
  }
}

/// Removable chip showing a selected filter item.
class _RemovableFilterChip extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onRemove;

  const _RemovableFilterChip({
    required this.label,
    required this.color,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.only(left: 10, right: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colorScheme.primary, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(
            width: 24,
            height: 24,
            child: IconButton(
              padding: EdgeInsets.zero,
              iconSize: 16,
              onPressed: onRemove,
              icon: Icon(
                Icons.close,
                color: colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Dropdown showing category autocomplete options.
class _CategoryOptionsDropdown extends StatelessWidget {
  final List<({String id, String name, Color color})> options;
  final ValueChanged<({String id, String name, Color color})> onSelected;

  const _CategoryOptionsDropdown({
    required this.options,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Align(
      alignment: Alignment.bottomLeft,
      child: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(8),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 200, maxWidth: 300),
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 4),
            shrinkWrap: true,
            itemCount: options.length,
            itemBuilder: (context, index) {
              final option = options[index];
              return ListTile(
                dense: true,
                leading: Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: option.color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: theme.colorScheme.outline.withValues(alpha: 0.3),
                    ),
                  ),
                ),
                title: Text(
                  option.name,
                  style: theme.textTheme.bodyMedium,
                ),
                onTap: () => onSelected(option),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Dropdown showing location autocomplete options.
class _LocationOptionsDropdown extends StatelessWidget {
  final List<({String id, String name})> options;
  final ValueChanged<({String id, String name})> onSelected;

  const _LocationOptionsDropdown({
    required this.options,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Align(
      alignment: Alignment.bottomLeft,
      child: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(8),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 200, maxWidth: 300),
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 4),
            shrinkWrap: true,
            itemCount: options.length,
            itemBuilder: (context, index) {
              final option = options[index];
              return ListTile(
                dense: true,
                leading: Icon(
                  Icons.location_on_outlined,
                  size: 20,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                title: Text(
                  option.name,
                  style: theme.textTheme.bodyMedium,
                ),
                onTap: () => onSelected(option),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// List of filtered expenses with pagination.
class _FilteredExpenseList extends StatelessWidget {
  final List<Expense> expenses;
  final ScrollController scrollController;
  final bool canLoadMore;

  const _FilteredExpenseList({
    required this.expenses,
    required this.scrollController,
    required this.canLoadMore,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: scrollController,
      // +1 for loading indicator when more available
      itemCount: expenses.length + (canLoadMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= expenses.length) {
          return const _LoadingIndicator();
        }
        return _ExpenseItem(expense: expenses[index]);
      },
    );
  }
}

/// Loading indicator shown at bottom during pagination.
class _LoadingIndicator extends StatelessWidget {
  const _LoadingIndicator();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}

/// Individual expense item in the filtered list.
class _ExpenseItem extends StatelessWidget {
  final Expense expense;

  const _ExpenseItem({required this.expense});

  @override
  Widget build(BuildContext context) {
    final categoryController = context.read<CategoryController>();
    final locationController = context.read<LocationController>();
    final currencyRegistry = context.read<CurrencyRegistry>();
    final expenseController = context.read<ExpenseController>();
    final settingsController = context.read<SettingsController>();

    final category = expense.categoryId != null
        ? categoryController.get(expense.categoryId!)
        : null;
    final location = expense.locationId != null
        ? locationController.get(expense.locationId!)
        : null;
    final currency = currencyRegistry.getByCode(expense.currencyCode);
    final primaryCurrency = currencyRegistry.getByCode(
      settingsController.primaryCurrency,
    );

    // Use stored primary currency conversion if primary hasn't changed
    int? convertedAmountMinor;
    if (expense.currencyCode != settingsController.primaryCurrency &&
        expense.hasPrimaryConversion &&
        expense.primaryCurrencyCode == settingsController.primaryCurrency) {
      convertedAmountMinor = expense.amountInPrimary;
    }

    return ExpenseTile(
      expense: expense,
      category: category,
      location: location,
      currency: currency,
      primaryCurrency: primaryCurrency,
      convertedAmountMinor: convertedAmountMinor,
      onEdit: () => _navigateToEdit(context),
      onDelete: () => _handleDelete(context, expenseController),
    );
  }

  void _navigateToEdit(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EditTransactionScreen(expense: expense),
      ),
    );
  }

  void _handleDelete(BuildContext context, ExpenseController controller) {
    final removed = controller.delete(expense.id);

    if (removed != null) {
      Toast.show(
        context,
        message: 'Transaction deleted',
        actionLabel: 'Undo',
        onAction: () => controller.add(removed),
      );
    }
  }
}
