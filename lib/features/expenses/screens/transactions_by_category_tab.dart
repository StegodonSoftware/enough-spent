import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/home_shell.dart';
import '../../categories/screens/manage_categories_screen.dart';
import '../../currency/data/currency_registry.dart';
import '../../currency/formatters/currency_formatter.dart';
import '../../settings/settings_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/toast/toast.dart';
import '../../../core/widgets/empty_state.dart';
import '../../categories/category_controller.dart';
import '../../categories/models/expense_category.dart';
import '../../locations/location_controller.dart';
import '../expense_constants.dart';
import '../expense_controller.dart';
import '../widgets/collapsible_section_header.dart';
import '../widgets/expense_tile.dart';
import 'edit_transaction_screen.dart';

/// Sort options for categories.
enum CategorySortOrder {
  mostUsed('Most Used'),
  highestTotal('Highest Total'),
  alphabetical('A-Z');

  final String label;
  const CategorySortOrder(this.label);
}

class TransactionsByCategoryTab extends StatefulWidget {
  const TransactionsByCategoryTab({super.key});

  @override
  State<TransactionsByCategoryTab> createState() =>
      TransactionsByCategoryTabState();
}

class TransactionsByCategoryTabState extends State<TransactionsByCategoryTab> {
  late final ScrollController _scrollController;

  /// Tracks which category is currently expanded (null = all collapsed).
  String? _expandedCategoryId;

  /// Current sort order for categories.
  CategorySortOrder _sortOrder = CategorySortOrder.mostUsed;

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
    final categoryController = context.watch<CategoryController>();

    final grouped = expenseController.expensesByCategory;

    if (grouped.isEmpty) {
      return EmptyState(
        icon: Icons.category_outlined,
        title: 'No transactions yet',
        subtitle: 'Your expenses will be grouped by category here',
        actionLabel: 'Add Expense',
        onAction: () => HomeNavigation.goToAddExpense(context),
      );
    }

    final sortedCategoryIds = _getSortedCategoryIds(expenseController, categoryController);

    return Scaffold(
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          for (final categoryId in sortedCategoryIds) ...[
            _CollapsibleCategoryHeader(
              categoryId: categoryId,
              isExpanded: _expandedCategoryId == categoryId,
              onToggle: () => _toggleCategory(categoryId),
            ),
            if (_expandedCategoryId == categoryId) ...[
              _CategoryExpenseList(categoryId: categoryId),
              _CategoryLoadMore(categoryId: categoryId),
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
            heroTag: 'manage_categories',
            onPressed: _navigateToCategoryManagement,
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: theme.colorScheme.onPrimary,
            tooltip: 'Manage categories',
            child: const Icon(Icons.tune),
          ),
          const SizedBox(height: 8),
          FloatingActionButton.small(
            heroTag: 'jump_to_category',
            onPressed: _showCategoryPicker,
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: theme.colorScheme.onPrimary,
            tooltip: 'Jump to category',
            child: const Icon(Icons.list),
          ),
        ],
      ),
    );
  }

  void _navigateToCategoryManagement() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const CategoryManagementScreen()),
    );
  }

  List<String> _getSortedCategoryIds(
    ExpenseController expenseController,
    CategoryController categoryController,
  ) {
    switch (_sortOrder) {
      case CategorySortOrder.mostUsed:
        return expenseController.orderedCategoryIds.toList();
      case CategorySortOrder.highestTotal:
        return expenseController.categoryTotalsAllTime
            .map((ct) => ct.categoryId)
            .toList();
      case CategorySortOrder.alphabetical:
        return expenseController.categoryIdsSortedAlphabetically;
    }
  }

  void _toggleCategory(String categoryId) {
    setState(() {
      if (_expandedCategoryId == categoryId) {
        _expandedCategoryId = null;
      } else {
        _expandedCategoryId = categoryId;
      }
    });
  }

  void _showCategoryPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => _CategoryPickerSheet(
        initialSortOrder: _sortOrder,
        onSortOrderChanged: (order) {
          setState(() => _sortOrder = order);
        },
        onCategorySelected: (categoryId) {
          Navigator.of(sheetContext).pop();
          _jumpToCategory(categoryId);
        },
      ),
    );
  }

  void _jumpToCategory(String categoryId) {
    final expenseController = context.read<ExpenseController>();
    final categoryIds = _getSortedCategoryIds(
      expenseController,
      context.read<CategoryController>(),
    );

    final index = categoryIds.indexOf(categoryId);
    if (index == -1) return;

    // Collapse all, then expand target
    setState(() {
      _expandedCategoryId = categoryId;
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

class _CollapsibleCategoryHeader extends StatelessWidget {
  final String categoryId;
  final bool isExpanded;
  final VoidCallback onToggle;

  const _CollapsibleCategoryHeader({
    required this.categoryId,
    required this.isExpanded,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final appColors = context.appColors;
    final category = context.read<CategoryController>().get(categoryId);
    final expenseController = context.read<ExpenseController>();
    final settingsController = context.read<SettingsController>();
    final currencyRegistry = context.read<CurrencyRegistry>();

    final totalMinor = expenseController.totalForCategory(categoryId);
    final primaryCurrency = currencyRegistry.getByCode(
      settingsController.primaryCurrency,
    );
    final formattedTotal = CurrencyFormatter.formatMinor(
      totalMinor,
      primaryCurrency,
    );

    final expenseCount =
        expenseController.expensesByCategory[categoryId]?.length ?? 0;

    // Determine indicator color:
    // - Uncategorized (null category): use uncategorizedBorder color
    // - Inactive category: use inactiveCategoryFill color
    // - Active category: use category's color
    final Color indicatorColor;
    if (category == null) {
      indicatorColor = appColors.uncategorizedBorder;
    } else if (!category.isActive) {
      indicatorColor = appColors.inactiveCategoryFill;
    } else {
      indicatorColor = category.color;
    }

    return CollapsibleSectionHeader(
      leading: CategoryColorIndicator(
        color: indicatorColor,
        isSolid: category != null,
      ),
      title: category?.name ?? 'Uncategorized',
      trailing: formattedTotal,
      itemCount: expenseCount,
      isExpanded: isExpanded,
      onToggle: onToggle,
    );
  }
}

class _CategoryExpenseList extends StatelessWidget {
  final String categoryId;

  const _CategoryExpenseList({required this.categoryId});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ExpenseController>();
    final categoryController = context.read<CategoryController>();
    final locationController = context.read<LocationController>();
    final currencyRegistry = context.read<CurrencyRegistry>();
    final settingsController = context.read<SettingsController>();

    final expenses = controller.visibleForCategory(categoryId);
    final category = categoryController.get(categoryId);
    final primaryCurrency = currencyRegistry.getByCode(
      settingsController.primaryCurrency,
    );

    return SliverList.builder(
      itemCount: expenses.length,
      itemBuilder: (context, index) {
        final expense = expenses[index];
        final location = expense.locationId != null
            ? locationController.get(expense.locationId!)
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
          showCategory: false,
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

class _CategoryLoadMore extends StatelessWidget {
  final String categoryId;

  const _CategoryLoadMore({required this.categoryId});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ExpenseController>();

    if (!controller.canLoadMoreForCategory(categoryId)) {
      return const SliverToBoxAdapter(child: SizedBox(height: 8));
    }

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Center(
          child: TextButton(
            onPressed: () {
              controller.loadMoreForCategory(categoryId);
            },
            child: const Text('Load more'),
          ),
        ),
      ),
    );
  }
}

/// Bottom sheet for picking a category to jump to.
class _CategoryPickerSheet extends StatefulWidget {
  final CategorySortOrder initialSortOrder;
  final ValueChanged<CategorySortOrder> onSortOrderChanged;
  final ValueChanged<String> onCategorySelected;

  const _CategoryPickerSheet({
    required this.initialSortOrder,
    required this.onSortOrderChanged,
    required this.onCategorySelected,
  });

  @override
  State<_CategoryPickerSheet> createState() => _CategoryPickerSheetState();
}

class _CategoryPickerSheetState extends State<_CategoryPickerSheet> {
  late CategorySortOrder _sortOrder;

  @override
  void initState() {
    super.initState();
    _sortOrder = widget.initialSortOrder;
  }

  void _updateSortOrder(CategorySortOrder order) {
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
    final categoryController = context.watch<CategoryController>();
    final settingsController = context.read<SettingsController>();
    final currencyRegistry = context.read<CurrencyRegistry>();

    final sortedIds = _getSortedCategoryIds(expenseController, categoryController);

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
                    'Categories',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  // Sort toggle
                  PopupMenuButton<CategorySortOrder>(
                    initialValue: _sortOrder,
                    onSelected: _updateSortOrder,
                    itemBuilder: (context) => CategorySortOrder.values
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

            // Category list
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: sortedIds.length,
                itemBuilder: (context, index) {
                  final categoryId = sortedIds[index];
                  final category = categoryController.get(categoryId);
                  final expenseCount =
                      expenseController
                          .expensesByCategory[categoryId]
                          ?.length ??
                      0;
                  final total = expenseController.totalForCategory(categoryId);
                  final formattedTotal = CurrencyFormatter.formatMinor(
                    total,
                    primaryCurrency,
                  );

                  return _CategoryListTile(
                    category: category,
                    expenseCount: expenseCount,
                    formattedTotal: formattedTotal,
                    onTap: () => widget.onCategorySelected(categoryId),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  List<String> _getSortedCategoryIds(
    ExpenseController expenseController,
    CategoryController categoryController,
  ) {
    switch (_sortOrder) {
      case CategorySortOrder.mostUsed:
        return expenseController.orderedCategoryIds.toList();
      case CategorySortOrder.highestTotal:
        return expenseController.categoryTotalsAllTime
            .map((ct) => ct.categoryId)
            .toList();
      case CategorySortOrder.alphabetical:
        return expenseController.categoryIdsSortedAlphabetically;
    }
  }
}

class _CategoryListTile extends StatelessWidget {
  final ExpenseCategory? category;
  final int expenseCount;
  final String formattedTotal;
  final VoidCallback onTap;

  const _CategoryListTile({
    required this.category,
    required this.expenseCount,
    required this.formattedTotal,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final appColors = context.appColors;

    // Determine indicator color:
    // - Uncategorized (null category): use uncategorizedBorder color
    // - Inactive category: use inactiveCategoryFill color
    // - Active category: use category's color
    final Color indicatorColor;
    if (category == null) {
      indicatorColor = appColors.uncategorizedBorder;
    } else if (!category!.isActive) {
      indicatorColor = appColors.inactiveCategoryFill;
    } else {
      indicatorColor = category!.color;
    }

    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          color: indicatorColor,
          borderRadius: BorderRadius.circular(3),
        ),
      ),
      title: Text(category?.name ?? 'Uncategorized'),
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
