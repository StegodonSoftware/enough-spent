import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Central theme configuration for the Spending Tracker app.
///
/// Implements the "Energized Calm" brand guidelines with:
/// - Teal primary color for energy and action
/// - Muted pastels for categories
/// - Clean typography with Manrope font family
abstract final class AppTheme {
  // ───────────────────────────────────────────────────────────────────────────
  // Brand Colors (from BRANDING.md)
  // ───────────────────────────────────────────────────────────────────────────

  static const _background = Color(0xFFF2F7F7);
  static const _surface = Color(0xFFFFFFFF);
  static const _textPrimary = Color(0xFF1F2937);
  static const _textSecondary = Color(0xFF4B5563);
  static const _primary = Color(0xFF2E8B96);
  static const _primaryVariant = Color(0xFF25707A);
  static const _error = Color(0xFFCB8F7A); // Muted rust
  static const _divider = Color(0xFFE5E7EB);

  // ───────────────────────────────────────────────────────────────────────────
  // Light Theme
  // ───────────────────────────────────────────────────────────────────────────

  static ThemeData get light {
    final colorScheme = ColorScheme.light(
      // Primary - teal for energy and action
      primary: _primary,
      onPrimary: Colors.white,
      primaryContainer: _primary.withValues(alpha: 0.12),
      onPrimaryContainer: _primaryVariant,

      // Secondary - using primary variant for cohesion
      secondary: _primaryVariant,
      onSecondary: Colors.white,
      secondaryContainer: _primaryVariant.withValues(alpha: 0.12),
      onSecondaryContainer: _primaryVariant,

      // Surface colors
      surface: _surface,
      onSurface: _textPrimary,
      onSurfaceVariant: _textSecondary,

      // Surface container hierarchy (M3)
      surfaceContainerLowest: _surface,
      surfaceContainerLow: _background,
      surfaceContainer: _background,
      surfaceContainerHigh: _divider.withValues(alpha: 0.5),
      surfaceContainerHighest: _divider,

      // Error states
      error: _error,
      onError: Colors.white,
      errorContainer: _error.withValues(alpha: 0.12),
      onErrorContainer: _error,

      // Outline/divider
      outline: _divider,
      outlineVariant: _divider.withValues(alpha: 0.5),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: _background,

      // AppBar
      appBarTheme: AppBarTheme(
        backgroundColor: _background,
        foregroundColor: _textPrimary,
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: false,
        titleTextStyle: GoogleFonts.manrope(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: _textPrimary,
        ),
      ),

      // Bottom Navigation
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: _surface,
        selectedItemColor: _primary,
        unselectedItemColor: _textSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),

      // Cards
      cardTheme: CardThemeData(
        color: _surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),

      // Chips - tight padding, readable text
      chipTheme: ChipThemeData(
        backgroundColor: colorScheme.surfaceContainerHighest,
        selectedColor: _primary.withValues(alpha: 0.2),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        labelPadding: const EdgeInsets.symmetric(horizontal: 4),
        labelStyle: GoogleFonts.manrope(
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),

      // Filled Buttons (primary actions) - tight but tappable
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: _primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          minimumSize: const Size(48, 40),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: GoogleFonts.manrope(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // Outlined Buttons - match filled button sizing
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: _primary,
          side: BorderSide(color: _primary),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          minimumSize: const Size(48, 40),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: GoogleFonts.manrope(
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),

      // Text Buttons - minimal padding
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: _primary,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          minimumSize: const Size(40, 36),
          textStyle: GoogleFonts.manrope(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),

      // Input Decoration
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: _divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: _divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: _primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: _error),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        hintStyle: GoogleFonts.manrope(
          color: _textSecondary.withValues(alpha: 0.6),
        ),
      ),

      // Divider
      dividerTheme: DividerThemeData(
        color: _divider,
        thickness: 1,
        space: 1,
      ),

      // Dialogs - ensure opaque backgrounds (M3 surface tint can look translucent)
      dialogTheme: DialogThemeData(
        backgroundColor: _surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),

      // DatePicker - ensure opaque backgrounds
      datePickerTheme: DatePickerThemeData(
        backgroundColor: _surface,
        surfaceTintColor: Colors.transparent,
        headerBackgroundColor: _primary,
        headerForegroundColor: Colors.white,
        dayBackgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return _primary;
          }
          return Colors.transparent;
        }),
        dayForegroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return Colors.white;
          }
          return _textPrimary;
        }),
        todayBackgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return _primary;
          }
          return Colors.transparent;
        }),
        todayForegroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return Colors.white;
          }
          return _primary;
        }),
        todayBorder: BorderSide(color: _primary),
        yearBackgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return _primary;
          }
          return Colors.transparent;
        }),
        yearForegroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return Colors.white;
          }
          return _textPrimary;
        }),
      ),

      // Typography
      textTheme: _buildTextTheme(),

      // Extension
      extensions: [AppColors.light()],
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Typography (Manrope font family via Google Fonts)
  // ───────────────────────────────────────────────────────────────────────────

  static TextTheme _buildTextTheme() {
    return TextTheme(
      // Display styles (large titles/totals: 28-34pt)
      displayLarge: GoogleFonts.manrope(
        fontSize: 34,
        fontWeight: FontWeight.w700,
        color: _textPrimary,
        height: 1.3,
      ),
      displayMedium: GoogleFonts.manrope(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        color: _textPrimary,
        height: 1.3,
      ),

      // Headline styles (section headings: 20-24pt)
      headlineLarge: GoogleFonts.manrope(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: _textPrimary,
        height: 1.4,
      ),
      headlineMedium: GoogleFonts.manrope(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: _textPrimary,
        height: 1.4,
      ),

      // Title styles (subheadings, category labels)
      titleLarge: GoogleFonts.manrope(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: _textPrimary,
        height: 1.4,
      ),
      titleMedium: GoogleFonts.manrope(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: _textPrimary,
        height: 1.5,
      ),
      titleSmall: GoogleFonts.manrope(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: _textPrimary,
        height: 1.5,
      ),

      // Body styles (main content: 16-18pt)
      bodyLarge: GoogleFonts.manrope(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: _textPrimary,
        height: 1.5,
      ),
      bodyMedium: GoogleFonts.manrope(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: _textPrimary,
        height: 1.5,
      ),
      bodySmall: GoogleFonts.manrope(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: _textSecondary,
        height: 1.5,
      ),

      // Label styles (secondary labels, hints: 12-14pt)
      labelLarge: GoogleFonts.manrope(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: _textPrimary,
        height: 1.5,
      ),
      labelMedium: GoogleFonts.manrope(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: _textSecondary,
        height: 1.5,
      ),
      labelSmall: GoogleFonts.manrope(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: _textSecondary,
        height: 1.5,
      ),
    );
  }
}
