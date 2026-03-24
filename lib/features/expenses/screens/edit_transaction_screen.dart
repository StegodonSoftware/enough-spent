import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/currency/currency_service.dart';
import '../../../core/toast/toast.dart';
import '../../../core/widgets/amount_field.dart';
import '../../../core/widgets/category_chip_selector.dart';
import '../../currency/data/currency_registry.dart';
import '../../currency/models/currency.dart';
import '../../currency/widgets/currency_picker_sheet.dart';
import '../../settings/settings_controller.dart';

import '../models/expense.dart';
import '../expense_controller.dart';
import '../../categories/category_controller.dart';
import '../../locations/location_controller.dart';
import '../../locations/widgets/location_picker_sheet.dart';

class EditTransactionScreen extends StatefulWidget {
  final Expense expense;

  const EditTransactionScreen({super.key, required this.expense});

  @override
  State<EditTransactionScreen> createState() => _EditTransactionScreenState();
}

class _EditTransactionScreenState extends State<EditTransactionScreen> {
  late int? _amountMinor;
  late String _currencyCode;
  late String? _categoryId;
  late String? _locationId;
  late DateTime _date;
  late TextEditingController _noteController;

  @override
  void initState() {
    super.initState();
    _amountMinor = widget.expense.amountMinor;
    _currencyCode = widget.expense.currencyCode;
    _categoryId = widget.expense.categoryId;
    _locationId = widget.expense.locationId;
    _date = widget.expense.date;
    _noteController = TextEditingController(text: widget.expense.note ?? '');
    _noteController.addListener(_onFieldChanged);
  }

  void _onFieldChanged() => setState(() {});

  @override
  void dispose() {
    _noteController.removeListener(_onFieldChanged);
    _noteController.dispose();
    super.dispose();
  }

  bool get _hasChanges {
    final originalNote = widget.expense.note ?? '';
    final currentNote = _noteController.text.trim();

    return _amountMinor != widget.expense.amountMinor ||
        _currencyCode != widget.expense.currencyCode ||
        _categoryId != widget.expense.categoryId ||
        _locationId != widget.expense.locationId ||
        _date != widget.expense.date ||
        currentNote != originalNote;
  }

  void _save() {
    if (_amountMinor == null) return;
    final amountMinor = _amountMinor!;

    final trimmedNote = _noteController.text.trim();
    final currencyService = context.read<CurrencyService>();
    final settings = context.read<SettingsController>();

    // Recalculate primary currency conversion if amount, currency, or the
    // primary currency changed (the latter can happen if the user navigates to
    // settings and changes primary currency while this screen is still open).
    int? amountInPrimary = widget.expense.amountInPrimary;
    String? primaryCurrencyCode = widget.expense.primaryCurrencyCode;
    double? rateToPrimary = widget.expense.rateToPrimary;
    DateTime? conversionDate = widget.expense.conversionDate;

    final amountChanged = amountMinor != widget.expense.amountMinor;
    final currencyChanged = _currencyCode != widget.expense.currencyCode;
    final primaryCurrencyChanged =
        widget.expense.primaryCurrencyCode != settings.primaryCurrency;

    if (currencyChanged || primaryCurrencyChanged) {
      // Currency context changed — must recalculate with current rate.
      final currentPrimary = settings.primaryCurrency;
      final conversion = currencyService.convert(
        amountMinor: amountMinor,
        from: _currencyCode,
        to: currentPrimary,
      );
      amountInPrimary = conversion;
      primaryCurrencyCode = currentPrimary;
      conversionDate = conversion != null ? currencyService.ratesTimestamp : null;

      // Calculate exchange rate: 1 [currencyCode] = X [primaryCurrency]
      if (_currencyCode != currentPrimary && conversion != null) {
        final fromRate = currencyService.getRateToUsd(_currencyCode);
        final toRate = currencyService.getRateFromUsd(currentPrimary);
        if (fromRate != null && toRate != null) {
          rateToPrimary = fromRate * toRate;
        }
      } else {
        rateToPrimary = null;
      }
    } else if (amountChanged) {
      // Only the amount changed — preserve the historical exchange rate.
      if (_currencyCode == primaryCurrencyCode) {
        // Same currency as primary, direct copy.
        amountInPrimary = amountMinor;
      } else if (rateToPrimary != null && primaryCurrencyCode != null) {
        // Re-apply stored rate to new amount; conversionDate is preserved.
        final registry = context.read<CurrencyRegistry>();
        final fromNumToBasic = registry.getByCode(_currencyCode).numToBasic;
        final toNumToBasic = registry.getByCode(primaryCurrencyCode).numToBasic;
        amountInPrimary =
            (amountMinor * rateToPrimary * toNumToBasic / fromNumToBasic)
                .round();
      } else {
        // No stored rate (legacy expense) — fall back to current rate.
        final currentPrimary = settings.primaryCurrency;
        final conversion = currencyService.convert(
          amountMinor: amountMinor,
          from: _currencyCode,
          to: currentPrimary,
        );
        amountInPrimary = conversion;
        primaryCurrencyCode = currentPrimary;
        conversionDate = conversion != null ? currencyService.ratesTimestamp : null;
        if (_currencyCode != currentPrimary && conversion != null) {
          final fromRate = currencyService.getRateToUsd(_currencyCode);
          final toRate = currencyService.getRateFromUsd(currentPrimary);
          if (fromRate != null && toRate != null) {
            rateToPrimary = fromRate * toRate;
          }
        }
      }
    }

    final updated = widget.expense.copyWith(
      amountMinor: amountMinor,
      currencyCode: _currencyCode,
      categoryId: _categoryId,
      clearCategoryId: _categoryId == null,
      locationId: _locationId,
      clearLocationId: _locationId == null,
      date: _date,
      note: trimmedNote.isEmpty ? null : trimmedNote,
      clearNote: trimmedNote.isEmpty && widget.expense.note != null,
      amountInPrimary: amountInPrimary,
      primaryCurrencyCode: primaryCurrencyCode,
      rateToPrimary: rateToPrimary,
      conversionDate: conversionDate,
    );

    context.read<ExpenseController>().update(updated);
    Toast.show(context, message: 'Expense updated');
    Navigator.pop(context);
  }

  Future<void> _selectLocation() async {
    final locationController = context.read<LocationController>();
    final result = await showLocationPickerSheet(
      context,
      selectedLocationId: _locationId,
      locations: locationController.all,
    );

    if (result == null) return;

    switch (result) {
      case LocationCleared():
        setState(() => _locationId = null);
      case LocationSelected(:final location):
        setState(() => _locationId = location.id);
      case LocationCreateNew(:final name):
        final newLocation = locationController.addLocation(name);
        if (newLocation != null) {
          setState(() => _locationId = newLocation.id);
        }
    }
  }

  Future<void> _selectCurrency(Currency currentCurrency) async {
    final selected = await showCurrencyPickerSheet(
      context,
      selectedCode: currentCurrency.code,
    );

    if (selected != null && selected.code != currentCurrency.code) {
      setState(() => _currencyCode = selected.code);
    }
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (picked != null) {
      setState(() => _date = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final registry = context.watch<CurrencyRegistry>();
    final currency = registry.getByCode(_currencyCode);
    final categoryController = context.watch<CategoryController>();
    final categories = categoryController.active;
    final theme = Theme.of(context);

    // Check if the expense has an inactive category
    final inactiveCategory = _categoryId != null
        ? categoryController.inactive
              .where((c) => c.id == _categoryId)
              .firstOrNull
        : null;

    return PopScope(
      canPop: !_hasChanges,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _showDiscardDialog();
      },
      child: Scaffold(
      appBar: AppBar(title: const Text('Edit Expense')),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Amount
                  AmountField(
                    currency: currency,
                    initialMinorUnits: _amountMinor,
                    autofocus: false,
                    maxMinorUnits: Expense.maxAmountMinor,
                    onChangedMinor: (v) => setState(() => _amountMinor = v),
                  ),

                  const SizedBox(height: 16),

                  // Currency & Date row
                  Row(
                    children: [
                      // Currency chip
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Currency',
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 8),
                            OutlinedButton.icon(
                              onPressed: () => _selectCurrency(currency),
                              icon: const Icon(
                                Icons.currency_exchange,
                                size: 16,
                              ),
                              label: Text(
                                '${currency.symbol} ${currency.code}',
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(width: 16),

                      // Date picker
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Date',
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 8),
                            OutlinedButton.icon(
                              onPressed: _selectDate,
                              icon: const Icon(Icons.calendar_today, size: 16),
                              label: Text(DateFormat.yMMMd().format(_date)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  if (_currencyCode != widget.expense.currencyCode) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Currency changed — conversion will use today\'s rate',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),

                  // Category
                  Text(
                    'Category',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  CategoryChipSelector(
                    categories: categories,
                    selectedCategoryId: _categoryId,
                    onChanged: (id) => setState(() => _categoryId = id),
                    inactiveCategory: inactiveCategory,
                  ),

                  const SizedBox(height: 20),

                  // Location
                  Text(
                    'Location',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _LocationSelector(
                    locationId: _locationId,
                    onTap: _selectLocation,
                    onClear: () => setState(() => _locationId = null),
                  ),

                  const SizedBox(height: 20),

                  // Note
                  Text(
                    'Note',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _noteController,
                    decoration: const InputDecoration(
                      hintText: 'Add a note (optional)',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                    maxLength: Expense.maxNoteLength,
                    textCapitalization: TextCapitalization.sentences,
                  ),

                  const SizedBox(height: 24),

                  // Timestamp metadata
                  _TimestampMetadata(expense: widget.expense),
                ],
              ),
            ),
          ),

          // Save button - fixed at bottom
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _amountMinor != null && _hasChanges ? _save : null,
                child: const Text('Save Changes'),
              ),
            ),
          ),
        ],
      ),
    ),
    );
  }

  void _showDiscardDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Discard changes?'),
        content: const Text('You have unsaved changes that will be lost.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Keep Editing'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              Navigator.pop(context);
            },
            child: const Text('Discard'),
          ),
        ],
      ),
    );
  }
}

/// Displays creation and last edited timestamps for an expense.
///
/// Shows both timestamps if they differ, otherwise just shows created time.
class _TimestampMetadata extends StatelessWidget {
  final Expense expense;

  const _TimestampMetadata({required this.expense});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final createdFormatted = DateFormat(
      'MMM d, y, h:mm a',
    ).format(expense.createdAt);
    final updatedFormatted = DateFormat(
      'MMM d, y, h:mm a',
    ).format(expense.updatedAt);

    // Only show both timestamps if they differ by more than 1 second
    final hasBeenEdited =
        expense.updatedAt.difference(expense.createdAt).inSeconds > 1;

    return Center(
      child: Text(
        hasBeenEdited
            ? 'Created $createdFormatted · Last edited $updatedFormatted'
            : 'Created $createdFormatted',
        style: theme.textTheme.labelSmall?.copyWith(
          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

/// Tappable chip/button for selecting a location.
/// Shows the current location with initials badge, or "Add location" if none.
class _LocationSelector extends StatelessWidget {
  final String? locationId;
  final VoidCallback onTap;
  final VoidCallback onClear;

  const _LocationSelector({
    required this.locationId,
    required this.onTap,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final locationController = context.watch<LocationController>();
    final location = locationId != null
        ? locationController.get(locationId!)
        : null;

    if (location == null) {
      // No location selected
      return OutlinedButton.icon(
        onPressed: onTap,
        icon: const Icon(Icons.add_location_alt_outlined, size: 16),
        label: const Text('Add location'),
      );
    }

    // Location selected - show with initials badge and clear button
    return InputChip(
      avatar: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: colorScheme.primary,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Text(
          location.initials,
          style: theme.textTheme.labelSmall?.copyWith(
            color: colorScheme.onPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 10,
          ),
        ),
      ),
      label: Text(location.name),
      labelStyle: theme.textTheme.labelLarge?.copyWith(
        color: colorScheme.onSurface,
      ),
      onPressed: onTap,
      deleteIcon: Icon(Icons.close, size: 18, color: colorScheme.onSurfaceVariant),
      onDeleted: onClear,
    );
  }
}
