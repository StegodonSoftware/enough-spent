import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:dotted_border/dotted_border.dart';

import '../../currency/formatters/currency_formatter.dart';
import '../../currency/models/currency.dart';
import '../../../core/theme/app_colors.dart';
import '../../categories/models/expense_category.dart';
import '../../locations/models/location.dart';
import '../models/expense.dart';

/// A tile displaying an expense with expand/collapse and swipe actions.
///
/// Collapsed: Shows category, date, and amount with swipe-to-reveal actions.
/// When the expense currency differs from primary currency, shows converted
/// amount with a ⇄ icon indicator.
/// Expanded: Shows full details including note, with visible action buttons.
class ExpenseTile extends StatefulWidget {
  final Expense expense;
  final ExpenseCategory? category;
  final Location? location;
  final Currency currency;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  /// Whether to show the category indicator (hide when grouped by category).
  final bool showCategory;

  /// Primary currency for displaying converted amounts.
  /// When expense currency differs from primary, shows converted amount.
  final Currency? primaryCurrency;

  /// Amount converted to primary currency (in minor units).
  /// Only provided when expense currency differs from primary currency.
  final int? convertedAmountMinor;

  const ExpenseTile({
    super.key,
    required this.expense,
    required this.category,
    this.location,
    required this.currency,
    required this.onEdit,
    required this.onDelete,
    this.showCategory = true,
    this.primaryCurrency,
    this.convertedAmountMinor,
  });

  @override
  State<ExpenseTile> createState() => _ExpenseTileState();
}

class _ExpenseTileState extends State<ExpenseTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    if (_expanded) {
      return _buildExpanded(context);
    }
    return _buildCollapsedWithSwipe(context);
  }

  Widget _buildCollapsedWithSwipe(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Dismissible(
      key: ValueKey('${widget.expense.id}_swipe'),
      direction: DismissDirection.horizontal,
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.endToStart) {
          widget.onDelete();
        } else {
          widget.onEdit();
        }
        return false; // Don't actually dismiss
      },
      background: Container(
        color: colorScheme.primaryContainer,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        child: Icon(Icons.edit, color: colorScheme.onPrimaryContainer),
      ),
      secondaryBackground: Container(
        color: colorScheme.errorContainer,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: Icon(Icons.delete, color: colorScheme.onErrorContainer),
      ),
      child: _buildCollapsedContent(context),
    );
  }

  Widget _buildCollapsedContent(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border(
          bottom: BorderSide(color: colorScheme.outline, width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => setState(() => _expanded = true),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              // Category color indicator
              _buildEndCap(context),
              // Main content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Category name + date
                    Text(
                      _buildSubtitle(),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    // Amount (converted if different currency, with indicator)
                    _buildAmountDisplay(theme, colorScheme, collapsed: true),
                  ],
                ),
              ),

              // Location initials badge (for quick visual scanning)
              // Only show in collapsed view if location is known
              if (widget.location != null)
                _LocationBadge(location: widget.location, size: 28),

              // Expand hint
              Icon(
                Icons.chevron_right,
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEndCap(BuildContext context) {
    final appColors = context.appColors;
    final categoryColor = _getCategoryColor(widget.category, appColors);

    if (widget.category == null) {
      return Container(
        margin: const EdgeInsets.only(right: 12),
        child: DottedBorder(
          options: RoundedRectDottedBorderOptions(
            dashPattern: const [8, 4],
            strokeWidth: 2,
            color: categoryColor,
            radius: const Radius.circular(3),
          ),
          child: Container(
            width: 7,
            height: 37,
            // no color = transparent
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(3)),
          ),
        ),
      );
    }

    return Container(
      width: 12,
      height: 40,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: categoryColor,
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }

  Widget _buildExpanded(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final note = widget.expense.note;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border(
          bottom: BorderSide(color: colorScheme.outline, width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with collapse button
          InkWell(
            onTap: () => setState(() => _expanded = false),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
              child: Row(
                children: [
                  if (widget.showCategory) _buildEndCap(context),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _buildSubtitle(),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 2),
                        // Expanded view always shows original amount
                        _buildAmountDisplay(
                          theme,
                          colorScheme,
                          collapsed: false,
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.expand_less, color: colorScheme.onSurfaceVariant),
                ],
              ),
            ),
          ),

          // Details section
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Full date (date only, no time)
                _DetailRow(
                  icon: Icons.calendar_today,
                  label: DateFormat.yMMMMd().format(widget.expense.date),
                ),

                // Location
                _LocationDetailRow(location: widget.location),

                // Currency - always show primary currency
                _DetailRow(
                  icon: Icons.currency_exchange,
                  label:
                      '${widget.primaryCurrency?.name ?? widget.currency.name} (${widget.primaryCurrency?.code ?? widget.currency.code})',
                ),

                // Conversion details (if currency converted to primary)
                if (widget.convertedAmountMinor != null &&
                    widget.primaryCurrency != null)
                  _buildConversionDetailsSection(theme, colorScheme),

                // Note
                if (note != null && note.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(note, style: theme.textTheme.bodyMedium),
                    ),
                  ),
              ],
            ),
          ),

          // Action buttons
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: widget.onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Edit'),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: widget.onDelete,
                  icon: Icon(
                    Icons.delete_outline,
                    size: 18,
                    color: colorScheme.error,
                  ),
                  label: Text(
                    'Delete',
                    style: TextStyle(color: colorScheme.error),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the amount display for collapsed or expanded view.
  ///
  /// Shows the primary currency amount (if converted), otherwise original amount.
  /// When converted, displays a ⇄ symbol to indicate conversion.
  Widget _buildAmountDisplay(
    ThemeData theme,
    ColorScheme colorScheme, {
    required bool collapsed,
  }) {
    final hasConversion =
        widget.convertedAmountMinor != null && widget.primaryCurrency != null;

    final amount = hasConversion
        ? widget.convertedAmountMinor!
        : widget.expense.amountMinor;
    final currency = hasConversion ? widget.primaryCurrency! : widget.currency;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          CurrencyFormatter.formatMinor(amount, currency),
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        if (hasConversion) ...[
          const SizedBox(width: 6),
          Icon(
            Icons.currency_exchange,
            size: 16,
            color: colorScheme.onSurfaceVariant,
          ),
        ],
      ],
    );
  }

  Widget _buildConversionDetailsSection(
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    final originalAmount = CurrencyFormatter.formatMinor(
      widget.expense.amountMinor,
      widget.currency,
    );
    final rate = widget.expense.rateToPrimary;
    final conversionDate = widget.expense.conversionDate;

    // Build rate string: "1 USD = X [currencyCode]"
    final rateLabel = rate != null
        ? '1 ${widget.primaryCurrency!.code} = ${(1 / rate).toStringAsFixed(4)} ${widget.currency.code}'
        : 'Rate unavailable';

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with title and attribution info icon
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Conversion Details',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 6),
                Tooltip(
                  message: 'Exchange Rates By UniRateAPI\n(unirateapi.com)',
                  child: Icon(
                    Icons.info_outline,
                    size: 14,
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            // Responsive horizontal layout for conversion info
            Wrap(
              spacing: 16,
              runSpacing: 6,
              children: [
                // Original amount
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Original',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 10,
                      ),
                    ),
                    Text(
                      '$originalAmount ${widget.currency.code}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
                // Exchange rate
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Rate',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 10,
                      ),
                    ),
                    Text(
                      rateLabel,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
                // Conversion date (if available)
                if (conversionDate != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Rate date',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontSize: 10,
                        ),
                      ),
                      Text(
                        DateFormat.yMMMMd().format(conversionDate),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _buildSubtitle() {
    final categoryName = widget.category?.name ?? 'Uncategorized';
    final dateStr = _formatShortDate(widget.expense.date);

    // Location is shown via badge, not in subtitle
    if (widget.showCategory) {
      return '$categoryName · $dateStr';
    }
    return dateStr;
  }

  String _formatShortDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final expenseDate = DateTime(date.year, date.month, date.day);
    final diff = today.difference(expenseDate).inDays;

    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff < 7) return DateFormat.EEEE().format(date); // "Monday"
    if (date.year == now.year) {
      return DateFormat.MMMd().format(date); // "Jan 15"
    }
    return DateFormat.yMMMd().format(date); // "Jan 15, 2024"
  }

  /// Returns the appropriate color for the category indicator.
  /// - Uncategorized (null): uncategorizedBorder color
  /// - Inactive category: inactiveCategoryFill color
  /// - Active category: category's color
  Color _getCategoryColor(ExpenseCategory? category, AppColors appColors) {
    if (category == null) {
      return appColors.uncategorizedBorder;
    }
    if (!category.isActive) {
      return appColors.inactiveCategoryFill;
    }
    return category.color;
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;

  const _DetailRow({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Circular badge showing location initials.
///
/// Uses primary color for known locations, grey for unknown.
/// Size is configurable for different contexts.
class _LocationBadge extends StatelessWidget {
  final Location? location;
  final double size;

  const _LocationBadge({required this.location, this.size = 24});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Scale font size proportionally to badge size
    final fontSize = size * 0.4;

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
      width: size,
      height: size,
      margin: const EdgeInsets.only(right: 8),
      decoration: BoxDecoration(color: backgroundColor, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: theme.textTheme.labelSmall?.copyWith(
          color: textColor,
          fontWeight: FontWeight.w600,
          fontSize: fontSize,
        ),
      ),
    );
  }
}

/// Detail row for location with initials badge instead of icon.
class _LocationDetailRow extends StatelessWidget {
  final Location? location;

  const _LocationDetailRow({required this.location});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          // Initials badge (smaller version for detail row)
          _LocationBadge(location: location, size: 18),
          Expanded(
            child: Text(
              location?.name ?? 'Location Unknown',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
