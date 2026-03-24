import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../app/home_shell.dart';
import '../../currency/data/currency_registry.dart';
import '../../currency/formatters/currency_formatter.dart';
import '../../settings/settings_controller.dart';
import '../../../core/toast/toast.dart';
import '../../../core/widgets/empty_state.dart';
import '../../categories/category_controller.dart';
import '../../locations/location_controller.dart';
import '../expense_constants.dart';
import '../expense_controller.dart';
import '../models/expense.dart';
import '../models/expense_totals.dart';
import '../widgets/collapsible_section_header.dart';
import '../widgets/expense_tile.dart';
import 'edit_transaction_screen.dart';

/// Groups expenses by date period for display.
///
/// Uses a sealed class hierarchy for type-safe period handling.
/// Periods are: Today, Yesterday, This Week, Earlier This Month, then by month.
sealed class DateGroup {
  const DateGroup();

  String get label;

  /// Sort key for ordering groups (most recent first).
  int get sortKey;

  /// Whether this group should start collapsed.
  bool get startsCollapsed;
}

class TodayGroup extends DateGroup {
  const TodayGroup();

  @override
  String get label => 'Today';

  @override
  int get sortKey => 0;

  @override
  bool get startsCollapsed => false;

  @override
  bool operator ==(Object other) => other is TodayGroup;

  @override
  int get hashCode => runtimeType.hashCode;
}

class YesterdayGroup extends DateGroup {
  const YesterdayGroup();

  @override
  String get label => 'Yesterday';

  @override
  int get sortKey => 1;

  @override
  bool get startsCollapsed => false;

  @override
  bool operator ==(Object other) => other is YesterdayGroup;

  @override
  int get hashCode => runtimeType.hashCode;
}

class ThisWeekGroup extends DateGroup {
  const ThisWeekGroup();

  @override
  String get label => 'This Week';

  @override
  int get sortKey => 2;

  @override
  bool get startsCollapsed => false;

  @override
  bool operator ==(Object other) => other is ThisWeekGroup;

  @override
  int get hashCode => runtimeType.hashCode;
}

class EarlierThisMonthGroup extends DateGroup {
  const EarlierThisMonthGroup();

  @override
  String get label => 'Earlier This Month';

  @override
  int get sortKey => 3;

  @override
  bool get startsCollapsed => false;

  @override
  bool operator ==(Object other) => other is EarlierThisMonthGroup;

  @override
  int get hashCode => runtimeType.hashCode;
}

/// Groups expenses by calendar month (for older transactions).
class MonthGroup extends DateGroup {
  final int year;
  final int month;

  const MonthGroup(this.year, this.month);

  @override
  String get label {
    final date = DateTime(year, month);
    final now = DateTime.now();

    // Show "January" for current year, "January 2024" for past years
    if (year == now.year) {
      return DateFormat.MMMM().format(date);
    }
    return DateFormat.yMMMM().format(date);
  }

  @override
  int get sortKey {
    // Higher sort key = older (appears later)
    return 1000 + (10000 - year) * 12 + (12 - month);
  }

  @override
  bool get startsCollapsed => true;

  @override
  bool operator ==(Object other) =>
      other is MonthGroup && other.year == year && other.month == month;

  @override
  int get hashCode => Object.hash(year, month);
}

/// Holds a date group with its expenses and calculated total.
class _GroupData {
  final DateGroup group;
  final List<Expense> expenses;
  final int itemCount;
  final int totalMinor;
  final List<CurrencyAmount> currencyBreakdown;

  const _GroupData({
    required this.group,
    required this.expenses,
    required this.itemCount,
    required this.totalMinor,
    this.currencyBreakdown = const [],
  });
}

class TransactionsByDateTab extends StatefulWidget {
  const TransactionsByDateTab({super.key});

  @override
  State<TransactionsByDateTab> createState() => _TransactionsByDateTabState();
}

class _TransactionsByDateTabState extends State<TransactionsByDateTab> {
  late final ScrollController _scrollController;

  /// The currently expanded group (null = all collapsed).
  DateGroup? _expandedGroup;

  /// True once the initial group has been auto-expanded on first render.
  bool _initialGroupSet = false;

  static const double _loadMoreThreshold = 200.0;

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
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;

    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;

    if (maxScroll - currentScroll <= _loadMoreThreshold) {
      final controller = context.read<ExpenseController>();
      if (controller.canLoadMore) {
        controller.loadMore();
      }
    }
  }

  bool _isCollapsed(DateGroup group) => _expandedGroup != group;

  void _toggleGroup(DateGroup group) {
    setState(() {
      _expandedGroup = _expandedGroup == group ? null : group;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final expenseController = context.watch<ExpenseController>();
    final firstDayOfWeek = context.select<SettingsController, int>(
      (s) => s.firstDayOfWeek,
    );

    if (expenseController.visibleExpenses.isEmpty) {
      return EmptyState(
        icon: Icons.receipt_long_outlined,
        title: 'No transactions yet',
        subtitle: 'Start tracking your spending by adding your first expense',
        actionLabel: 'Add Expense',
        onAction: () => HomeNavigation.goToAddExpense(context),
      );
    }

    final groupedData = _buildGroupData(expenseController, firstDayOfWeek);

    // Auto-expand the most recent group (Today if it exists, otherwise the
    // first available group) on first render. Done inline so the initial frame
    // renders correctly without a visible flash.
    if (!_initialGroupSet && groupedData.isNotEmpty) {
      _initialGroupSet = true;
      _expandedGroup = groupedData.first.group;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;

      final maxScroll = _scrollController.position.maxScrollExtent;
      if (maxScroll == 0 && expenseController.canLoadMore) {
        expenseController.loadMore();
      }
    });

    return Scaffold(
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          for (final data in groupedData) ...[
            _CollapsibleDateHeader(
              group: data.group,
              totalMinor: data.totalMinor,
              currencyBreakdown: data.currencyBreakdown,
              itemCount: data.itemCount,
              isCollapsed: _isCollapsed(data.group),
              onToggle: () => _toggleGroup(data.group),
            ),
            _AnimatedExpenseList(
              expenses: data.expenses,
              isCollapsed: _isCollapsed(data.group),
            ),
          ],
          SliverToBoxAdapter(
            child: _buildLoadMoreIndicator(expenseController),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
      ),
      floatingActionButton: FloatingActionButton.small(
        onPressed: () => _showDateGroupPicker(groupedData),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        tooltip: 'Jump to date',
        child: const Icon(Icons.list),
      ),
    );
  }

  void _showDateGroupPicker(List<_GroupData> groupedData) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => _DateGroupPickerSheet(
        groups: groupedData,
        onGroupSelected: (group) {
          Navigator.of(sheetContext).pop();
          _jumpToDateGroup(group, groupedData);
        },
      ),
    );
  }

  void _jumpToDateGroup(DateGroup targetGroup, List<_GroupData> groupedData) {
    final targetIndex = groupedData.indexWhere((d) => d.group == targetGroup);
    if (targetIndex == -1) return;

    setState(() => _expandedGroup = targetGroup);

    // All groups before the target are collapsed, so offset is headers-only.
    final offset = targetIndex * ExpenseLayout.categoryHeaderHeight;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        offset.clamp(0.0, _scrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    });
  }

  List<_GroupData> _buildGroupData(ExpenseController expenseController, int firstDayOfWeek) {
    // Group ALL expenses so totals and counts are stable regardless of pagination.
    final allGrouped = _groupByDatePeriod(expenseController.all, firstDayOfWeek);

    // IDs of currently loaded expenses — used to filter which tiles to render.
    final visibleIds = expenseController.visibleExpenses
        .map((e) => e.id)
        .toSet();

    final sortedEntries = allGrouped.entries.toList()
      ..sort((a, b) => a.key.sortKey.compareTo(b.key.sortKey));

    final result = <_GroupData>[];

    for (final entry in sortedEntries) {
      final allInGroup = entry.value;

      // Only surface groups that have at least one loaded tile.
      final visibleInGroup = allInGroup
          .where((e) => visibleIds.contains(e.id))
          .toList(growable: false);

      if (visibleInGroup.isEmpty) continue;

      // Currency breakdown: pure aggregation of native amounts — no conversion.
      final currencyTotals = <String, int>{};
      for (final expense in allInGroup) {
        currencyTotals.update(
          expense.currencyCode,
          (v) => v + expense.amountMinor,
          ifAbsent: () => expense.amountMinor,
        );
      }

      result.add(_GroupData(
        group: entry.key,
        expenses: visibleInGroup,
        itemCount: allInGroup.length,
        totalMinor: expenseController.totalForExpenses(allInGroup),
        currencyBreakdown: CurrencyBreakdownHelper.fromMap(currencyTotals),
      ));
    }

    return result;
  }

  Widget _buildLoadMoreIndicator(ExpenseController controller) {
    return const SizedBox(height: 32);
  }
}

/// Groups expenses into date-based periods.
Map<DateGroup, List<Expense>> _groupByDatePeriod(List<Expense> expenses, int firstDayOfWeek) {
  final now = DateTime.now();
  final today = DateUtils.dateOnly(now);
  final yesterday = today.subtract(const Duration(days: 1));
  final daysFromWeekStart = (today.weekday - firstDayOfWeek + 7) % 7;
  final startOfWeek = today.subtract(Duration(days: daysFromWeekStart));
  final startOfMonth = DateTime(now.year, now.month);

  final Map<DateGroup, List<Expense>> groups = {};

  for (final expense in expenses) {
    final expenseDate = DateUtils.dateOnly(expense.date);
    final group = _resolveGroup(
      expenseDate,
      today,
      yesterday,
      startOfWeek,
      startOfMonth,
    );

    groups.putIfAbsent(group, () => []).add(expense);
  }

  return groups;
}

DateGroup _resolveGroup(
  DateTime expenseDate,
  DateTime today,
  DateTime yesterday,
  DateTime startOfWeek,
  DateTime startOfMonth,
) {
  if (expenseDate == today) {
    return const TodayGroup();
  }

  if (expenseDate == yesterday) {
    return const YesterdayGroup();
  }

  if (!expenseDate.isBefore(startOfWeek)) {
    return const ThisWeekGroup();
  }

  if (!expenseDate.isBefore(startOfMonth)) {
    return const EarlierThisMonthGroup();
  }

  return MonthGroup(expenseDate.year, expenseDate.month);
}

class _CollapsibleDateHeader extends StatelessWidget {
  final DateGroup group;
  final int totalMinor;
  final List<CurrencyAmount> currencyBreakdown;
  final int itemCount;
  final bool isCollapsed;
  final VoidCallback onToggle;

  const _CollapsibleDateHeader({
    required this.group,
    required this.totalMinor,
    required this.currencyBreakdown,
    required this.itemCount,
    required this.isCollapsed,
    required this.onToggle,
  });

  String? _formatCurrencyBreakdown(CurrencyRegistry registry) {
    if (currencyBreakdown.length <= 1) return null;

    const maxDisplay = 4;
    final display = currencyBreakdown.take(maxDisplay);

    final formatted = display.map((ca) {
      final currency = registry.getByCode(ca.currencyCode);
      return CurrencyFormatter.formatMinor(ca.amountMinor, currency);
    }).join(' • ');

    if (currencyBreakdown.length > maxDisplay) {
      return '$formatted • +${currencyBreakdown.length - maxDisplay} more';
    }

    return formatted;
  }

  @override
  Widget build(BuildContext context) {
    final settingsController = context.read<SettingsController>();
    final currencyRegistry = context.read<CurrencyRegistry>();

    final primaryCurrency = currencyRegistry.getByCode(
      settingsController.primaryCurrency,
    );
    final formattedTotal = CurrencyFormatter.formatMinor(
      totalMinor,
      primaryCurrency,
    );

    final subtitle = _formatCurrencyBreakdown(currencyRegistry);

    return CollapsibleSectionHeader(
      leading: const SizedBox.shrink(),
      title: group.label,
      subtitle: subtitle,
      trailing: formattedTotal,
      itemCount: itemCount,
      isExpanded: !isCollapsed,
      onToggle: onToggle,
    );
  }
}

class _AnimatedExpenseList extends StatelessWidget {
  final List<Expense> expenses;
  final bool isCollapsed;

  const _AnimatedExpenseList({
    required this.expenses,
    required this.isCollapsed,
  });

  @override
  Widget build(BuildContext context) {
    if (isCollapsed) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    return SliverList.builder(
      itemCount: expenses.length,
      itemBuilder: (context, index) => _ExpenseTileBuilder(
        key: ValueKey(expenses[index].id),
        expense: expenses[index],
      ),
    );
  }
}

class _ExpenseTileBuilder extends StatelessWidget {
  final Expense expense;

  const _ExpenseTileBuilder({super.key, required this.expense});

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
    final primaryCurrencyCode = settingsController.primaryCurrency;
    final primaryCurrency = currencyRegistry.getByCode(primaryCurrencyCode);

    // Use stored primary currency conversion if available and primary hasn't changed
    int? convertedAmountMinor;
    if (expense.currencyCode != primaryCurrencyCode &&
        expense.hasPrimaryConversion &&
        expense.primaryCurrencyCode == primaryCurrencyCode) {
      convertedAmountMinor = expense.amountInPrimary;
    }
    // Note: If primary currency has changed, we'd need to re-convert using current rates.
    // This is handled by ExpenseController's _convertToPrimary() for totals.
    // For individual tiles, we show the original currency if conversion isn't available.

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
    controller.softDelete(expense.id);

    Toast.show(
      context,
      message: 'Transaction deleted',
      actionLabel: 'Undo',
      onAction: () => controller.restorePendingDelete(),
    );
  }
}

/// Bottom sheet for picking a date group to jump to.
class _DateGroupPickerSheet extends StatelessWidget {
  final List<_GroupData> groups;
  final ValueChanged<DateGroup> onGroupSelected;

  const _DateGroupPickerSheet({
    required this.groups,
    required this.onGroupSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final settingsController = context.read<SettingsController>();
    final currencyRegistry = context.read<CurrencyRegistry>();
    final primaryCurrency = currencyRegistry.getByCode(
      settingsController.primaryCurrency,
    );

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Column(
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

            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Jump to',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),

            const Divider(height: 1),

            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: groups.length,
                itemBuilder: (context, index) {
                  final data = groups[index];
                  final formattedTotal = CurrencyFormatter.formatMinor(
                    data.totalMinor,
                    primaryCurrency,
                  );
                  final count = data.itemCount;

                  return ListTile(
                    title: Text(data.group.label),
                    subtitle: Text(
                      '$count transaction${count == 1 ? '' : 's'}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    trailing: Text(
                      formattedTotal,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    onTap: () => onGroupSelected(data.group),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
