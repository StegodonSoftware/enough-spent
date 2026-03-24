import 'package:flutter/material.dart';

/// App-specific colors that extend the Material ColorScheme.
///
/// Access via: `Theme.of(context).extension<AppColors>()!`
///
/// These colors are for app-specific needs that don't map to Material's
/// semantic color system (e.g., category palette, custom feedback colors).
class AppColors extends ThemeExtension<AppColors> {
  /// Muted pastel palette for expense categories.
  /// Used in category chips, chart segments, and expense indicators.
  final List<Color> categoryPalette;

  /// Static default palette for use without BuildContext (e.g., controllers).
  static const List<Color> defaultCategoryPalette = [
    Color(0xFFA7C4E0), // Soft blue
    Color(0xFFB8A7E0), // Soft purple
    Color(0xFFE0A7C4), // Soft pink
    Color(0xFFE0B8A7), // Soft peach
    Color(0xFFA7E0C4), // Soft mint
    Color(0xFFC4E0A7), // Soft lime
    Color(0xFFE0D9A7), // Soft gold
    Color(0xFFA7E0E0), // Soft cyan
    Color(0xFFFAD4A0), // Soft caramel
    Color(0xFFA7A7E0), // Soft indigo
  ];

  /// Color for uncategorized expenses (dashed border).
  final Color uncategorizedBorder;

  /// Color for inactive categories (grey fill replacing original color).
  final Color inactiveCategoryFill;

  /// Positive feedback color (save confirmations, success states).
  final Color success;

  /// Informational/neutral color (hints, offline indicators).
  final Color info;

  const AppColors({
    required this.categoryPalette,
    required this.uncategorizedBorder,
    required this.inactiveCategoryFill,
    required this.success,
    required this.info,
  });

  /// Light theme colors from brand guidelines.
  factory AppColors.light() {
    return const AppColors(
      categoryPalette: defaultCategoryPalette,
      uncategorizedBorder: Color(0xFF9CA3AF),
      inactiveCategoryFill: Color(0xFF9CA3AF),
      success: Color(0xFF6EC6B8), // Teal-mint
      info: Color(0xFFA8B4D4), // Soft lavender-blue
    );
  }

  /// Returns a category color by index, cycling through the palette.
  Color categoryColor(int index) {
    return categoryPalette[index % categoryPalette.length];
  }

  @override
  AppColors copyWith({
    List<Color>? categoryPalette,
    Color? uncategorizedBorder,
    Color? inactiveCategoryFill,
    Color? success,
    Color? info,
  }) {
    return AppColors(
      categoryPalette: categoryPalette ?? this.categoryPalette,
      uncategorizedBorder: uncategorizedBorder ?? this.uncategorizedBorder,
      inactiveCategoryFill: inactiveCategoryFill ?? this.inactiveCategoryFill,
      success: success ?? this.success,
      info: info ?? this.info,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;

    return AppColors(
      categoryPalette: [
        for (int i = 0; i < categoryPalette.length; i++)
          Color.lerp(categoryPalette[i], other.categoryPalette[i], t)!,
      ],
      uncategorizedBorder: Color.lerp(
        uncategorizedBorder,
        other.uncategorizedBorder,
        t,
      )!,
      inactiveCategoryFill: Color.lerp(
        inactiveCategoryFill,
        other.inactiveCategoryFill,
        t,
      )!,
      success: Color.lerp(success, other.success, t)!,
      info: Color.lerp(info, other.info, t)!,
    );
  }
}

/// Convenience extension for easy access to AppColors.
extension AppColorsExtension on BuildContext {
  /// Access app-specific colors: `context.appColors.categoryPalette`
  AppColors get appColors => Theme.of(this).extension<AppColors>()!;
}
