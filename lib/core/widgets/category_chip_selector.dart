import 'package:flutter/material.dart';

import '../../features/categories/models/expense_category.dart';
import '../theme/app_colors.dart';

/// A reusable category chip selector with clear selected/unselected states.
///
/// Selected chips have full-color background and a subtle drop shadow for depth.
/// Unselected chips have a faded background with readable dark text.
/// Uses the color stored in each category.
///
/// Optionally displays an inactive category (for editing expenses that have
/// an inactive category assigned) in a separate row with dashed border styling.
class CategoryChipSelector extends StatelessWidget {
  /// Active categories available for selection.
  final List<ExpenseCategory> categories;

  /// Currently selected category ID (can be active or inactive).
  final String? selectedCategoryId;

  /// Callback when selection changes.
  final ValueChanged<String?> onChanged;

  /// Optional inactive category to display (for editing expenses with inactive categories).
  /// Shown in a separate row above active categories with dashed border styling.
  final ExpenseCategory? inactiveCategory;

  /// Background opacity for unselected chips (faded but visible).
  static const _unselectedBackgroundAlpha = 0.35;

  /// Shadow blur radius for selected chips.
  static const _selectedBlur = 4.0;

  /// Shadow offset for selected chips.
  static const _selectedOffset = Offset(0, 2);

  const CategoryChipSelector({
    super.key,
    required this.categories,
    required this.selectedCategoryId,
    required this.onChanged,
    this.inactiveCategory,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final appColors = context.appColors;

    final isInactiveCategorySelected =
        inactiveCategory != null && selectedCategoryId == inactiveCategory!.id;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Inactive category row (if provided)
        if (inactiveCategory != null) ...[
          _InactiveCategoryChip(
            category: inactiveCategory!,
            isSelected: isInactiveCategorySelected,
            hasOtherSelection:
                selectedCategoryId != null && !isInactiveCategorySelected,
            colorScheme: colorScheme,
            appColors: appColors,
            onTap: () => onChanged(
              isInactiveCategorySelected ? null : inactiveCategory!.id,
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Active categories
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: categories.map((cat) {
            final isSelected = selectedCategoryId == cat.id;

            return _CategoryChip(
              category: cat,
              chipColor: cat.color,
              isSelected: isSelected,
              colorScheme: colorScheme,
              onTap: () => onChanged(isSelected ? null : cat.id),
            );
          }).toList(),
        ),
      ],
    );
  }
}

/// Individual category chip with selection styling.
class _CategoryChip extends StatelessWidget {
  final ExpenseCategory category;
  final Color chipColor;
  final bool isSelected;
  final ColorScheme colorScheme;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.category,
    required this.chipColor,
    required this.isSelected,
    required this.colorScheme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Border for selected state
    final border = isSelected
        ? Border.all(color: colorScheme.primary, width: 1.5)
        : null;

    // Shadow for selected state (3D effect)
    final boxShadow = isSelected
        ? [
            BoxShadow(
              color: chipColor.withValues(alpha: 0.4),
              blurRadius: CategoryChipSelector._selectedBlur,
              offset: CategoryChipSelector._selectedOffset,
            ),
          ]
        : null;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? chipColor
              : chipColor.withValues(
                  alpha: CategoryChipSelector._unselectedBackgroundAlpha,
                ),
          borderRadius: BorderRadius.circular(8),
          border: border,
          boxShadow: boxShadow,
        ),
        child: Text(
          category.name,
          style: theme.textTheme.labelLarge?.copyWith(
            color: colorScheme.onSurface,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

/// Inactive category chip with grey fill styling.
///
/// Per BRANDING.md: Inactive categories use grey fill (#9CA3AF) replacing
/// the original category color, and show "(Inactive)" suffix.
class _InactiveCategoryChip extends StatelessWidget {
  final ExpenseCategory category;
  final bool isSelected;
  final bool hasOtherSelection;
  final ColorScheme colorScheme;
  final AppColors appColors;
  final VoidCallback onTap;

  const _InactiveCategoryChip({
    required this.category,
    required this.isSelected,
    required this.hasOtherSelection,
    required this.colorScheme,
    required this.appColors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Only dim if another category is selected
    final shouldDim = hasOtherSelection;

    // Border for selected state
    final border = isSelected
        ? Border.all(color: colorScheme.primary, width: 1.5)
        : null;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: shouldDim
              ? appColors.inactiveCategoryFill.withValues(
                  alpha: CategoryChipSelector._unselectedBackgroundAlpha,
                )
              : appColors.inactiveCategoryFill,
          borderRadius: BorderRadius.circular(8),
          border: border,
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: appColors.inactiveCategoryFill.withValues(alpha: 0.4),
                    blurRadius: CategoryChipSelector._selectedBlur,
                    offset: CategoryChipSelector._selectedOffset,
                  ),
                ]
              : null,
        ),
        child: Text(
          '${category.name} (Inactive)',
          style: theme.textTheme.labelLarge?.copyWith(
            color: colorScheme.onSurface,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

/// Custom painter for dashed border effect.
// ignore: unused_element
class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double borderRadius;
  final double dashWidth;
  final double dashSpace;

  _DashedBorderPainter({
    required this.color,
    required this.strokeWidth,
    required this.borderRadius,
    // ignore: unused_element_parameter
    this.dashWidth = 5,
    // ignore: unused_element_parameter
    this.dashSpace = 3,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0, 0, size.width, size.height),
          Radius.circular(borderRadius),
        ),
      );

    final dashPath = _createDashedPath(path);
    canvas.drawPath(dashPath, paint);
  }

  Path _createDashedPath(Path source) {
    final result = Path();
    for (final metric in source.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final len = dashWidth;
        result.addPath(
          metric.extractPath(distance, distance + len),
          Offset.zero,
        );
        distance += dashWidth + dashSpace;
      }
    }
    return result;
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) {
    return color != oldDelegate.color ||
        strokeWidth != oldDelegate.strokeWidth ||
        borderRadius != oldDelegate.borderRadius ||
        dashWidth != oldDelegate.dashWidth ||
        dashSpace != oldDelegate.dashSpace;
  }
}
