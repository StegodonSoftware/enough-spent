import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/toast/toast.dart';
import '../category_controller.dart';
import '../models/expense_category.dart';
import '../widgets/category_row.dart';
import '../../../core/widgets/color_picker.dart';

class CategoryManagementScreen extends StatefulWidget {
  const CategoryManagementScreen({super.key});

  @override
  State<CategoryManagementScreen> createState() =>
      _CategoryManagementScreenState();
}

class _CategoryManagementScreenState extends State<CategoryManagementScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<ExpenseCategory> _getFilteredCategories(
    CategoryController controller,
    String query,
  ) {
    return query.isEmpty
        ? controller.active
        : controller.active
              .where((c) => c.name.toLowerCase().contains(query.toLowerCase()))
              .toList();
  }

  void _onDelete(BuildContext context, ExpenseCategory category) {
    final controller = context.read<CategoryController>();
    final result = controller.deleteCategory(category.id);

    if (result.wasDeleted && result.category != null) {
      Toast.show(
        context,
        message: 'Category deleted',
        actionLabel: 'Undo',
        onAction: () => controller.restore(result.category!),
      );
    } else if (result.wasDeactivated) {
      Toast.show(context, message: 'Category is in use and was deactivated');
    }
  }

  void _onReactivate(BuildContext context, ExpenseCategory category) {
    final controller = context.read<CategoryController>();
    controller.restore(category);
    Toast.show(context, message: 'Category reactivated');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final categoryController = context.watch<CategoryController>();
    final query = _searchController.text.trim();
    final filteredCategories = _getFilteredCategories(
      categoryController,
      query,
    );
    final canAdd = categoryController.canAddCategory();
    final inactiveCount = categoryController.inactive.length;

    return Scaffold(
      appBar: AppBar(title: const Text('Manage Categories')),
      floatingActionButton: canAdd
          ? FloatingActionButton(
              onPressed: () => _showAddCategorySheet(context),
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
              child: const Icon(Icons.add),
            )
          : null,
      body: filteredCategories.isEmpty && inactiveCount == 0
          ? _EmptyState(
              hasQuery: query.isNotEmpty,
              onAdd: () => _showAddCategorySheet(context),
              onClearSearch: () {
                _searchController.clear();
                setState(() {});
              },
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Search categories...',
                          prefixIcon: const Icon(Icons.search),
                          border: const OutlineInputBorder(),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                          suffixIcon: query.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() {});
                                  },
                                )
                              : null,
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Text(
                            'Active',
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${filteredCategories.length}/${CategoryController.maxCategories}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: filteredCategories.isEmpty
                      ? Center(
                          child: Text(
                            query.isNotEmpty
                                ? 'No matching categories'
                                : 'No categories yet',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        )
                      : ListView.separated(
                          itemCount: filteredCategories.length,
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final category = filteredCategories[index];
                            final usageCount = categoryController.usageCount(
                              category.id,
                            );

                            return CategoryRow(
                              category: category,
                              usageCount: usageCount,
                              onTap: () => _editCategory(context, category),
                              onDeactivate: () => _onDelete(context, category),
                              onReactivate: () =>
                                  _onReactivate(context, category),
                            );
                          },
                        ),
                ),
                if (inactiveCount > 0 && query.isEmpty) ...[
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Text(
                          'Inactive',
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '$inactiveCount',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: _InactiveList(
                      onEdit: _editCategory,
                      onReactivate: _onReactivate,
                    ),
                  ),
                ],
              ],
            ),
    );
  }

  void _showAddCategorySheet(BuildContext context) {
    final nameController = TextEditingController();
    Color? selectedColor;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        final bottomPadding = MediaQuery.viewInsetsOf(sheetContext).bottom;
        final theme = Theme.of(sheetContext);
        final appColors = sheetContext.appColors;
        final categoryController = sheetContext.read<CategoryController>();
        final activeCount = categoryController.active.length;
        final isAtLimit = activeCount >= CategoryController.maxCategories;

        Color getSelectedColor() =>
            selectedColor ?? appColors.categoryPalette.first;

        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomPadding),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Add Category', style: theme.textTheme.titleLarge),
                      Text(
                        '$activeCount of ${CategoryController.maxCategories} used',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isAtLimit
                              ? theme.colorScheme.error
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Name'),
                    autofocus: true,
                    textCapitalization: TextCapitalization.words,
                    maxLength: ExpenseCategory.maxNameLength,
                    onChanged: (_) => setModalState(() {}),
                  ),

                  const SizedBox(height: 16),

                  Text(
                    'Color',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  CategoryColorPicker(
                    selected: getSelectedColor(),
                    onChanged: (c) {
                      setModalState(() {
                        selectedColor = c;
                      });
                    },
                  ),

                  const SizedBox(height: 16),

                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed:
                          nameController.text.trim().isNotEmpty && !isAtLimit
                          ? () {
                              context.read<CategoryController>().addCategory(
                                nameController.text.trim(),
                                getSelectedColor().toARGB32(),
                              );
                              Navigator.pop(context);
                              Toast.show(context, message: 'Category added');
                            }
                          : null,
                      child: const Text('Add'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _editCategory(BuildContext context, ExpenseCategory category) {
    final nameController = TextEditingController(text: category.name);
    Color selectedColor = category.color;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        final bottomPadding = MediaQuery.viewInsetsOf(sheetContext).bottom;

        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomPadding),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Edit Category',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),

                  const SizedBox(height: 16),

                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Name'),
                    autofocus: true,
                    textCapitalization: TextCapitalization.words,
                    maxLength: ExpenseCategory.maxNameLength,
                    onChanged: (_) => setModalState(() {}),
                  ),

                  const SizedBox(height: 16),

                  if (category.isActive) ...[
                    Text(
                      'Color',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    CategoryColorPicker(
                      selected: selectedColor,
                      onChanged: (c) {
                        setModalState(() {
                          selectedColor = c;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                  ],

                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: nameController.text.trim().isNotEmpty
                          ? () {
                              context.read<CategoryController>().update(
                                category.copyWith(
                                  name: nameController.text.trim(),
                                  colorValue: selectedColor.toARGB32(),
                                ),
                              );
                              Navigator.pop(context);
                            }
                          : null,
                      child: const Text('Save'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

/// Widget for displaying inactive categories.
class _InactiveList extends StatelessWidget {
  final Function(BuildContext, ExpenseCategory) onEdit;
  final Function(BuildContext, ExpenseCategory) onReactivate;

  const _InactiveList({required this.onEdit, required this.onReactivate});

  @override
  Widget build(BuildContext context) {
    return Consumer<CategoryController>(
      builder: (context, controller, _) {
        final inactive = controller.inactive;

        return ListView.separated(
          itemCount: inactive.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final category = inactive[index];
            final usageCount = controller.usageCount(category.id);

            return CategoryRow(
              category: category,
              usageCount: usageCount,
              onTap: () => onEdit(context, category),
              onReactivate: () => onReactivate(context, category),
            );
          },
        );
      },
    );
  }
}

/// Empty state shown when no categories exist or match search.
class _EmptyState extends StatelessWidget {
  final bool hasQuery;
  final VoidCallback onAdd;
  final VoidCallback onClearSearch;

  const _EmptyState({
    required this.hasQuery,
    required this.onAdd,
    required this.onClearSearch,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hasQuery ? Icons.search_off : Icons.category_outlined,
              size: 64,
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              hasQuery ? 'No matching categories' : 'No categories yet',
              style: theme.textTheme.titleMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              hasQuery
                  ? 'Try a different search term'
                  : 'Categories help you organize and track your spending patterns.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
            ),
            if (!hasQuery) ...[
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add),
                label: const Text('Add Category'),
              ),
            ] else ...[
              const SizedBox(height: 24),
              OutlinedButton(
                onPressed: onClearSearch,
                child: const Text('Clear Search'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
