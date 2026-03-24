import 'package:flutter/material.dart';

import '../models/expense_category.dart';

/// A category input field with horizontal scroll chips and autocomplete.
///
/// Features:
/// - Horizontal scroll row of category chips sorted by usage frequency
/// - Fixed-width chips that expand when selected to show full name
/// - Autocomplete text field for searching all categories
/// - Color dot indicator in dropdown options
class CategoryAutocompleteField extends StatefulWidget {
  /// All available categories.
  final List<ExpenseCategory> categories;

  /// Map of category ID to usage count for sorting.
  final Map<String, int> usageCounts;

  /// Currently selected category ID.
  final String? selectedCategoryId;

  /// Called when selection changes.
  final ValueChanged<String?> onChanged;

  const CategoryAutocompleteField({
    super.key,
    required this.categories,
    required this.usageCounts,
    required this.selectedCategoryId,
    required this.onChanged,
  });

  @override
  State<CategoryAutocompleteField> createState() =>
      _CategoryAutocompleteFieldState();
}

class _CategoryAutocompleteFieldState
    extends State<CategoryAutocompleteField> {
  late TextEditingController _textController;
  late FocusNode _focusNode;
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController();
    _focusNode = FocusNode();
    _scrollController = ScrollController();
    _focusNode.addListener(_onFocusChanged);
    _textController.addListener(_onTextChanged);
    _syncTextFromSelection();
  }

  @override
  void didUpdateWidget(CategoryAutocompleteField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedCategoryId != oldWidget.selectedCategoryId &&
        !_focusNode.hasFocus) {
      _syncTextFromSelection();
    }
  }

  void _onTextChanged() {
    setState(() {}); // Rebuild to update no-match hint visibility
  }

  void _onFocusChanged() {
    if (_focusNode.hasFocus) {
      // Scroll the field into view at the top of the scrollable area
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          Scrollable.ensureVisible(
            context,
            alignment: 0.0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        }
      });
    } else {
      _finalizeSelection();
    }
    setState(() {}); // Rebuild for focus-dependent hint visibility
  }

  void _finalizeSelection() {
    final text = _textController.text.trim();
    if (text.isEmpty) {
      if (widget.selectedCategoryId != null) {
        widget.onChanged(null);
      }
      return;
    }

    // Check if it matches an existing category (case-insensitive)
    final match = widget.categories
        .where((c) => c.name.toLowerCase() == text.toLowerCase())
        .firstOrNull;

    if (match != null && widget.selectedCategoryId != match.id) {
      widget.onChanged(match.id);
    }
  }

  void _syncTextFromSelection() {
    if (widget.selectedCategoryId != null) {
      final category = widget.categories
          .where((c) => c.id == widget.selectedCategoryId)
          .firstOrNull;
      _textController.text = category?.name ?? '';
    } else {
      _textController.text = '';
    }
  }

  @override
  void dispose() {
    _textController.removeListener(_onTextChanged);
    _focusNode.removeListener(_onFocusChanged);
    _textController.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _selectCategory(ExpenseCategory category) {
    _textController.text = category.name;
    widget.onChanged(category.id);
    _focusNode.unfocus();
  }

  void _clearSelection() {
    _textController.clear();
    widget.onChanged(null);
  }

  /// Categories sorted by usage count (descending).
  List<ExpenseCategory> get _sortedCategories {
    final sorted = List<ExpenseCategory>.from(widget.categories);
    sorted.sort((a, b) {
      final countA = widget.usageCounts[a.id] ?? 0;
      final countB = widget.usageCounts[b.id] ?? 0;
      return countB.compareTo(countA);
    });
    return sorted;
  }

  /// Whether the current query has any matching categories.
  bool get _hasMatches {
    final query = _textController.text.trim();
    if (query.isEmpty) return true;
    return widget.categories.any(
      (c) => c.name.toLowerCase().contains(query.toLowerCase()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Horizontal scroll row of category chips
        if (widget.categories.isNotEmpty) ...[
          SizedBox(
            height: 36,
            child: ListView.separated(
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              itemCount: _sortedCategories.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final category = _sortedCategories[index];
                final isSelected = widget.selectedCategoryId == category.id;
                return _CategoryChip(
                  category: category,
                  isSelected: isSelected,
                  onTap: () {
                    if (isSelected) {
                      _clearSelection();
                    } else {
                      _selectCategory(category);
                    }
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 10),
        ],

        // Autocomplete text field
        _buildAutocomplete(),

        // No-match guidance when search yields no results
        if (!_hasMatches && _focusNode.hasFocus) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                Icons.info_outline,
                size: 14,
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  'Category not found \u2014 add new categories in '
                  'Settings \u2192 Manage Categories',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildAutocomplete() {
    return Autocomplete<ExpenseCategory>(
      textEditingController: _textController,
      focusNode: _focusNode,
      optionsBuilder: (textEditingValue) {
        final query = textEditingValue.text.trim();
        if (query.isEmpty) {
          return const Iterable.empty();
        }

        return widget.categories.where(
          (c) => c.name.toLowerCase().contains(query.toLowerCase()),
        );
      },
      displayStringForOption: (category) => category.name,
      onSelected: _selectCategory,
      optionsViewBuilder: (context, onSelected, options) {
        return _OptionsDropdown(
          options: options.toList(),
          onSelected: onSelected,
        );
      },
      fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
        return _CategoryTextField(
          controller: controller,
          focusNode: focusNode,
          selectedCategory: widget.selectedCategoryId != null
              ? widget.categories
                  .where((c) => c.id == widget.selectedCategoryId)
                  .firstOrNull
              : null,
          onClear: _clearSelection,
          onSubmitted: (_) {
            onSubmitted();
            _finalizeSelection();
          },
        );
      },
    );
  }
}

/// Fixed-width category chip that expands when selected.
class _CategoryChip extends StatelessWidget {
  final ExpenseCategory category;
  final bool isSelected;
  final VoidCallback onTap;

  /// Width for unselected chips (truncated text).
  static const double _collapsedWidth = 88.0;

  /// Maximum width for expanded chips.
  static const double _maxExpandedWidth = 160.0;

  /// Animation duration.
  static const Duration _animationDuration = Duration(milliseconds: 180);

  /// Background opacity for unselected chips (faded but visible).
  static const double _unselectedBackgroundAlpha = 0.35;

  const _CategoryChip({
    required this.category,
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
        duration: _animationDuration,
        curve: Curves.easeOut,
        constraints: BoxConstraints(
          minWidth: _collapsedWidth,
          maxWidth: isSelected ? _maxExpandedWidth : _collapsedWidth,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? category.color
              : category.color.withValues(alpha: _unselectedBackgroundAlpha),
          borderRadius: BorderRadius.circular(8),
          border: isSelected
              ? Border.all(color: colorScheme.primary, width: 1.5)
              : null,
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: category.color.withValues(alpha: 0.4),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                category.name,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: colorScheme.onSurface,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Text field for category search.
class _CategoryTextField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ExpenseCategory? selectedCategory;
  final VoidCallback onClear;
  final ValueChanged<String> onSubmitted;

  const _CategoryTextField({
    required this.controller,
    required this.focusNode,
    required this.selectedCategory,
    required this.onClear,
    required this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    final hasValue = controller.text.trim().isNotEmpty;

    return TextField(
      controller: controller,
      focusNode: focusNode,
      decoration: InputDecoration(
        hintText: 'Search categories',
        border: const OutlineInputBorder(),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        prefixIcon: selectedCategory != null
            ? Padding(
                padding: const EdgeInsets.only(left: 12, right: 8),
                child: _ColorDot(color: selectedCategory!.color),
              )
            : const Icon(Icons.search, size: 20),
        prefixIconConstraints: const BoxConstraints(minWidth: 40),
        suffixIcon: hasValue
            ? IconButton(
                icon: const Icon(Icons.clear, size: 18),
                onPressed: onClear,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              )
            : null,
      ),
      textInputAction: TextInputAction.done,
      textCapitalization: TextCapitalization.words,
      onSubmitted: onSubmitted,
    );
  }
}

/// Small circular color indicator.
class _ColorDot extends StatelessWidget {
  final Color color;

  const _ColorDot({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
    );
  }
}

/// Dropdown showing autocomplete options with color dots.
class _OptionsDropdown extends StatelessWidget {
  final List<ExpenseCategory> options;
  final ValueChanged<ExpenseCategory> onSelected;

  const _OptionsDropdown({
    required this.options,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Align(
      alignment: Alignment.topLeft,
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
              final category = options[index];
              return ListTile(
                dense: true,
                leading: _ColorDot(color: category.color),
                title: Text(
                  category.name,
                  style: theme.textTheme.bodyMedium,
                ),
                onTap: () => onSelected(category),
              );
            },
          ),
        ),
      ),
    );
  }
}
