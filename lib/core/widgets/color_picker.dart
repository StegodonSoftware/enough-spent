import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Color picker for categories using the app's pastel palette.
class CategoryColorPicker extends StatelessWidget {
  final Color selected;
  final ValueChanged<Color> onChanged;

  const CategoryColorPicker({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final appColors = context.appColors;
    final colorScheme = Theme.of(context).colorScheme;

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: appColors.categoryPalette.map((color) {
        final isSelected = color.toARGB32() == selected.toARGB32();

        return GestureDetector(
          onTap: () => onChanged(color),
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color,
              border: Border.all(
                color: isSelected ? colorScheme.primary : Colors.transparent,
                width: 2.5,
              ),
              borderRadius: BorderRadius.circular(8),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: color.withValues(alpha: 0.4),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
          ),
        );
      }).toList(),
    );
  }
}
