import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/home_shell.dart';
import '../../currency/data/currency_registry.dart';
import '../../locations/screens/location_management_screen.dart';
import '../../currency/formatters/currency_formatter.dart';
import '../../settings/settings_controller.dart';
import '../../../core/toast/toast.dart';
import '../../../core/widgets/empty_state.dart';
import '../../categories/category_controller.dart';
import '../../locations/location_controller.dart';
import '../../locations/models/location.dart';
import '../expense_constants.dart';
import '../expense_controller.dart';
import '../widgets/collapsible_section_header.dart';
import '../widgets/expense_tile.dart';
import 'edit_transaction_screen.dart';

/// Sort options for locations.
enum LocationSortOrder {
  mostUsed('Most Used'),
  highestTotal('Highest Total'),
  alphabetical('A-Z');

  final String label;
  const LocationSortOrder(this.label);
}

class TransactionsByLocationTab extends StatefulWidget {
  const TransactionsByLocationTab({super.key});

  @override
  State<TransactionsByLocationTab> createState() =>
      TransactionsByLocationTabState();
}

class TransactionsByLocationTabState extends State<TransactionsByLocationTab> {
  late final ScrollController _scrollController;

  /// Tracks which location is currently expanded (null = all collapsed).
  String? _expandedLocationId;

  /// Current sort order for locations.
  LocationSortOrder _sortOrder = LocationSortOrder.mostUsed;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final expenseController = context.watch<ExpenseController>();
    context.watch<LocationController>(); // rebuild when location names change

    final grouped = expenseController.expensesByLocation;

    if (grouped.isEmpty) {
      return EmptyState(
        icon: Icons.location_on_outlined,
        title: 'No transactions yet',
        subtitle: 'Your expenses will be grouped by location here',
        actionLabel: 'Add Expense',
        onAction: () => HomeNavigation.goToAddExpense(context),
      );
    }

    final sortedLocationIds = _getSortedLocationIds(expenseController);

    return Scaffold(
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          for (final locationId in sortedLocationIds) ...[
            _CollapsibleLocationHeader(
              locationId: locationId,
              isExpanded: _expandedLocationId == locationId,
              onToggle: () => _toggleLocation(locationId),
            ),
            if (_expandedLocationId == locationId) ...[
              _LocationExpenseList(locationId: locationId),
              _LocationLoadMore(locationId: locationId),
            ],
          ],
          // Bottom padding
          const SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.small(
            heroTag: 'manage_locations',
            onPressed: _navigateToLocationManagement,
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: theme.colorScheme.onPrimary,
            tooltip: 'Manage locations',
            child: const Icon(Icons.tune),
          ),
          const SizedBox(height: 8),
          FloatingActionButton.small(
            heroTag: 'jump_to_location',
            onPressed: _showLocationPicker,
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: theme.colorScheme.onPrimary,
            tooltip: 'Jump to location',
            child: const Icon(Icons.list),
          ),
        ],
      ),
    );
  }

  void _navigateToLocationManagement() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const LocationManagementScreen()),
    );
  }

  List<String> _getSortedLocationIds(ExpenseController expenseController) {
    switch (_sortOrder) {
      case LocationSortOrder.mostUsed:
        return expenseController.orderedLocationIds.toList();
      case LocationSortOrder.highestTotal:
        return expenseController.locationTotalsAllTime
            .map((lt) => lt.locationId)
            .toList();
      case LocationSortOrder.alphabetical:
        return expenseController.locationIdsSortedAlphabetically;
    }
  }

  void _toggleLocation(String locationId) {
    setState(() {
      if (_expandedLocationId == locationId) {
        _expandedLocationId = null;
      } else {
        _expandedLocationId = locationId;
      }
    });
  }

  void _showLocationPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => _LocationPickerSheet(
        initialSortOrder: _sortOrder,
        onSortOrderChanged: (order) {
          setState(() => _sortOrder = order);
        },
        onLocationSelected: (locationId) {
          Navigator.of(sheetContext).pop();
          _jumpToLocation(locationId);
        },
      ),
    );
  }

  void _jumpToLocation(String locationId) {
    final expenseController = context.read<ExpenseController>();
    final locationIds = _getSortedLocationIds(expenseController);

    final index = locationIds.indexOf(locationId);
    if (index == -1) return;

    // Collapse all, then expand target
    setState(() {
      _expandedLocationId = locationId;
    });

    // Calculate offset (all collapsed = just headers)
    final offset = index * ExpenseLayout.categoryHeaderHeight;

    // Scroll after the frame to ensure layout is updated
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;

      _scrollController.animateTo(
        offset,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    });
  }
}

class _CollapsibleLocationHeader extends StatelessWidget {
  final String locationId;
  final bool isExpanded;
  final VoidCallback onToggle;

  const _CollapsibleLocationHeader({
    required this.locationId,
    required this.isExpanded,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final location = context.read<LocationController>().get(locationId);
    final expenseController = context.read<ExpenseController>();
    final settingsController = context.read<SettingsController>();
    final currencyRegistry = context.read<CurrencyRegistry>();

    final totalMinor = expenseController.totalForLocation(locationId);
    final primaryCurrency = currencyRegistry.getByCode(
      settingsController.primaryCurrency,
    );
    final formattedTotal = CurrencyFormatter.formatMinor(
      totalMinor,
      primaryCurrency,
    );

    final expenseCount =
        expenseController.expensesByLocation[locationId]?.length ?? 0;

    return CollapsibleSectionHeader(
      leading: _LocationIndicator(location: location),
      title: location?.name ?? 'No Location',
      trailing: formattedTotal,
      itemCount: expenseCount,
      isExpanded: isExpanded,
      onToggle: onToggle,
    );
  }
}

/// Circular badge showing location initials.
///
/// Uses primary color for known locations, grey for unknown.
/// Matches the location badge pattern used in ExpenseTile for consistency.
class _LocationIndicator extends StatelessWidget {
  final Location? location;

  const _LocationIndicator({
    required this.location,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Use grey for unknown locations, primary for known
    final isUnknown = location == null;
    final backgroundColor = isUnknown
        ? colorScheme.outlineVariant
        : colorScheme.primary;
    final textColor = isUnknown
        ? colorScheme.onSurfaceVariant
        : colorScheme.onPrimary;
    final initials = location?.initials ?? '?';

    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: backgroundColor,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: theme.textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w600,
          color: textColor,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _LocationExpenseList extends StatelessWidget {
  final String locationId;

  const _LocationExpenseList({required this.locationId});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ExpenseController>();
    final categoryController = context.read<CategoryController>();
    final locationController = context.read<LocationController>();
    final currencyRegistry = context.read<CurrencyRegistry>();
    final settingsController = context.read<SettingsController>();

    final expenses = controller.visibleForLocation(locationId);
    final location = locationController.get(locationId);
    final primaryCurrency = currencyRegistry.getByCode(
      settingsController.primaryCurrency,
    );

    return SliverList.builder(
      itemCount: expenses.length,
      itemBuilder: (context, index) {
        final expense = expenses[index];
        final category = expense.categoryId != null
            ? categoryController.get(expense.categoryId!)
            : null;
        final currency = currencyRegistry.getByCode(expense.currencyCode);

        // Use stored primary currency conversion if primary hasn't changed
        int? convertedAmountMinor;
        if (expense.currencyCode != settingsController.primaryCurrency &&
            expense.hasPrimaryConversion &&
            expense.primaryCurrencyCode == settingsController.primaryCurrency) {
          convertedAmountMinor = expense.amountInPrimary;
        }

        return ExpenseTile(
          key: ValueKey(expense.id),
          expense: expense,
          category: category,
          location: location,
          currency: currency,
          primaryCurrency: primaryCurrency,
          convertedAmountMinor: convertedAmountMinor,
          onEdit: () => _navigateToEdit(context, expense),
          onDelete: () => _handleDelete(context, expense),
        );
      },
    );
  }

  void _navigateToEdit(BuildContext context, expense) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EditTransactionScreen(expense: expense),
      ),
    );
  }

  void _handleDelete(BuildContext context, expense) {
    context.read<ExpenseController>().softDelete(expense.id);

    Toast.show(
      context,
      message: 'Transaction deleted',
      actionLabel: 'Undo',
      onAction: () {
        context.read<ExpenseController>().restorePendingDelete();
      },
    );
  }
}

class _LocationLoadMore extends StatelessWidget {
  final String locationId;

  const _LocationLoadMore({required this.locationId});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ExpenseController>();

    if (!controller.canLoadMoreForLocation(locationId)) {
      return const SliverToBoxAdapter(child: SizedBox(height: 8));
    }

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Center(
          child: TextButton(
            onPressed: () {
              controller.loadMoreForLocation(locationId);
            },
            child: const Text('Load more'),
          ),
        ),
      ),
    );
  }
}

/// Bottom sheet for picking a location to jump to.
class _LocationPickerSheet extends StatefulWidget {
  final LocationSortOrder initialSortOrder;
  final ValueChanged<LocationSortOrder> onSortOrderChanged;
  final ValueChanged<String> onLocationSelected;

  const _LocationPickerSheet({
    required this.initialSortOrder,
    required this.onSortOrderChanged,
    required this.onLocationSelected,
  });

  @override
  State<_LocationPickerSheet> createState() => _LocationPickerSheetState();
}

class _LocationPickerSheetState extends State<_LocationPickerSheet> {
  late LocationSortOrder _sortOrder;

  @override
  void initState() {
    super.initState();
    _sortOrder = widget.initialSortOrder;
  }

  void _updateSortOrder(LocationSortOrder order) {
    setState(() {
      _sortOrder = order;
    });
    widget.onSortOrderChanged(order);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final expenseController = context.watch<ExpenseController>();
    final locationController = context.watch<LocationController>();
    final settingsController = context.read<SettingsController>();
    final currencyRegistry = context.read<CurrencyRegistry>();

    final sortedIds = _getSortedLocationIds(expenseController);

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

            // Header with sort toggle
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 8, 8),
              child: Row(
                children: [
                  Text(
                    'Locations',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  // Sort toggle
                  PopupMenuButton<LocationSortOrder>(
                    initialValue: _sortOrder,
                    onSelected: _updateSortOrder,
                    itemBuilder: (context) => LocationSortOrder.values
                        .map(
                          (order) => PopupMenuItem(
                            value: order,
                            child: Row(
                              children: [
                                if (order == _sortOrder)
                                  Icon(
                                    Icons.check,
                                    size: 18,
                                    color: colorScheme.primary,
                                  )
                                else
                                  const SizedBox(width: 18),
                                const SizedBox(width: 8),
                                Text(order.label),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _sortOrder.label,
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: colorScheme.primary,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.arrow_drop_down,
                            size: 20,
                            color: colorScheme.primary,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // Location list
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: sortedIds.length,
                itemBuilder: (context, index) {
                  final locationId = sortedIds[index];
                  final location = locationController.get(locationId);
                  final expenseCount =
                      expenseController
                          .expensesByLocation[locationId]
                          ?.length ??
                      0;
                  final total = expenseController.totalForLocation(locationId);
                  final formattedTotal = CurrencyFormatter.formatMinor(
                    total,
                    primaryCurrency,
                  );

                  return _LocationListTile(
                    location: location,
                    expenseCount: expenseCount,
                    formattedTotal: formattedTotal,
                    onTap: () => widget.onLocationSelected(locationId),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  List<String> _getSortedLocationIds(ExpenseController expenseController) {
    switch (_sortOrder) {
      case LocationSortOrder.mostUsed:
        return expenseController.orderedLocationIds.toList();
      case LocationSortOrder.highestTotal:
        return expenseController.locationTotalsAllTime
            .map((lt) => lt.locationId)
            .toList();
      case LocationSortOrder.alphabetical:
        return expenseController.locationIdsSortedAlphabetically;
    }
  }
}

class _LocationListTile extends StatelessWidget {
  final Location? location;
  final int expenseCount;
  final String formattedTotal;
  final VoidCallback onTap;

  const _LocationListTile({
    required this.location,
    required this.expenseCount,
    required this.formattedTotal,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Use grey for unknown locations, primary for known
    final isUnknown = location == null;
    final backgroundColor = isUnknown
        ? colorScheme.outlineVariant
        : colorScheme.primary;
    final textColor = isUnknown
        ? colorScheme.onSurfaceVariant
        : colorScheme.onPrimary;

    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: backgroundColor,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Text(
          location?.initials ?? '?',
          style: theme.textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: textColor,
            fontSize: 12,
          ),
        ),
      ),
      title: Text(location?.name ?? 'No Location'),
      subtitle: Text(
        '$expenseCount transaction${expenseCount == 1 ? '' : 's'}',
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
    );
  }
}
