import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../ads/ad_service.dart';
import '../../ads/widgets/banner_ad_widget.dart';
import '../../expenses/models/expense.dart';
import '../../expenses/expense_controller.dart';
import '../../../core/widgets/amount_field.dart';
import '../../categories/widgets/category_autocomplete_field.dart';
import '../../currency/data/currency_registry.dart';
import '../../currency/models/currency.dart';
import '../../currency/widgets/currency_picker_sheet.dart';
import '../../settings/settings_controller.dart';
import '../../../core/currency/currency_service.dart';
import '../../categories/category_controller.dart';
import '../../categories/models/expense_category.dart';
import '../../locations/location_controller.dart';
import '../../locations/models/location.dart';
import '../../locations/widgets/location_autocomplete_field.dart';
import '../../../core/toast/toast.dart';

class QuickEntryScreen extends StatefulWidget {
  const QuickEntryScreen({super.key});

  @override
  State<QuickEntryScreen> createState() => _QuickEntryScreenState();
}

class _QuickEntryScreenState extends State<QuickEntryScreen> {
  int? _amountMinor;
  String? _selectedCategoryId;
  String? _selectedCurrencyCode; // null = use default from settings
  LocationSelection _locationSelection = const LocationSelection.none();
  DateTime _selectedDate = DateTime.now();
  Key _amountKey = UniqueKey();
  final _noteController = TextEditingController();
  final _amountFocusNode = FocusNode();

  /// Controls whether optional details section is expanded.
  /// Starts collapsed, stays open after save within session.
  bool _optionalExpanded = false;

  @override
  void dispose() {
    _noteController.dispose();
    _amountFocusNode.dispose();
    super.dispose();
  }

  /// Returns the effective currency code (locked > selected > primary).
  String _getEffectiveCurrencyCode(SettingsController settings) {
    if (settings.lockedCurrencyCode != null) {
      return settings.lockedCurrencyCode!;
    }
    return _selectedCurrencyCode ?? settings.primaryCurrency;
  }

  void _save() {
    if (_amountMinor == null) return;

    final settings = context.read<SettingsController>();
    final locationController = context.read<LocationController>();
    final currencyService = context.read<CurrencyService>();

    // Resolve location ID (create new location if needed)
    String? locationId;
    if (_locationSelection.isExisting) {
      locationId = _locationSelection.existingLocationId!;
    } else if (_locationSelection.isNew) {
      final newLocation = locationController.addLocation(
        _locationSelection.newLocationName!,
      );
      if (newLocation != null) {
        locationId = newLocation.id;
      }
    }

    // Convert to primary currency at creation time
    final currencyCode = _getEffectiveCurrencyCode(settings);
    final primaryCurrency = settings.primaryCurrency;

    // Convert from current currency to primary currency
    final primaryConversion = currencyService.convert(
      amountMinor: _amountMinor!,
      from: currencyCode,
      to: primaryCurrency,
    );

    // Calculate exchange rate: 1 [currencyCode] = X [primaryCurrency]
    double? rateToPrimary;
    if (currencyCode != primaryCurrency && primaryConversion != null) {
      final fromRate = currencyService.getRateToUsd(currencyCode);
      final toRate = currencyService.getRateFromUsd(primaryCurrency);
      if (fromRate != null && toRate != null) {
        rateToPrimary = fromRate * toRate;
      }
    }

    final expense = Expense(
      id: const Uuid().v4(),
      amountMinor: _amountMinor!,
      currencyCode: currencyCode,
      categoryId: _selectedCategoryId,
      locationId: locationId,
      date: _selectedDate,
      note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
      amountInPrimary: primaryConversion,
      primaryCurrencyCode: primaryCurrency,
      rateToPrimary: rateToPrimary,
      conversionDate: primaryConversion != null ? currencyService.ratesTimestamp : null,
    );

    context.read<ExpenseController>().add(expense);

    // Record expense for interstitial tracking (shown when leaving screen)
    context.read<AdService>().recordExpenseSaved();

    // Haptic feedback
    HapticFeedback.mediumImpact();

    // Show success toast
    Toast.show(
      context,
      message: 'Expense saved',
      duration: const Duration(seconds: 2),
    );

    // Reset form but keep optional section open
    setState(() {
      _amountMinor = null;
      _selectedCategoryId = null;
      // Keep locked currency, reset manual override
      if (settings.lockedCurrencyCode == null) {
        _selectedCurrencyCode = null;
      }
      _locationSelection = const LocationSelection.none();
      _selectedDate = DateTime.now();
      _noteController.clear();
      _amountKey = UniqueKey();
      // _optionalExpanded stays as-is, locked currency is in settings
    });

    // Return focus to amount field for next entry
    _amountFocusNode.requestFocus();
  }

  Future<void> _selectCurrency(Currency currentCurrency) async {
    final settings = context.read<SettingsController>();

    if (settings.lockedCurrencyCode != null) {
      _showLockedCurrencyDialog(currentCurrency);
      return;
    }

    final selected = await showCurrencyPickerSheet(
      context,
      selectedCode: currentCurrency.code,
    );

    if (selected != null && selected.code != currentCurrency.code) {
      setState(() => _selectedCurrencyCode = selected.code);
    }

    // Return focus to amount field
    _amountFocusNode.requestFocus();
  }

  void _showLockedCurrencyDialog(Currency lockedCurrency) {
    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.lock,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Currency Locked',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '${lockedCurrency.symbol} ${lockedCurrency.code}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              FilledButton.tonal(
                onPressed: () {
                  Navigator.pop(sheetContext);
                  _showUnlockConfirmation();
                },
                child: const Text('Unlock Currency'),
              ),
              const SizedBox(height: 8),
              FilledButton.tonal(
                onPressed: () {
                  Navigator.pop(sheetContext);
                  _changeLockCurrency(lockedCurrency);
                },
                child: const Text('Change Locked Currency'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () => Navigator.pop(sheetContext),
                child: const Text('Close'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showUnlockConfirmation() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Unlock Currency?'),
        content: const Text(
          'You can select different currencies again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              final settings = context.read<SettingsController>();
              settings.setLockedCurrencyCode(null);
              _amountFocusNode.requestFocus();
            },
            child: const Text('Unlock'),
          ),
        ],
      ),
    );
  }

  Future<void> _changeLockCurrency(Currency currentCurrency) async {
    final settings = context.read<SettingsController>();
    final selected = await showCurrencyPickerSheet(
      context,
      selectedCode: currentCurrency.code,
    );

    if (selected != null && mounted) {
      settings.setLockedCurrencyCode(selected.code);
      _amountFocusNode.requestFocus();
    }
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final settings = context.watch<SettingsController>();
    final registry = context.watch<CurrencyRegistry>();
    final currency = registry.getByCode(_getEffectiveCurrencyCode(settings));
    final categoryController = context.watch<CategoryController>();
    final categories = categoryController.active;
    final categoryUsageCounts = categoryController.allUsageCounts;
    final locationController = context.watch<LocationController>();
    final canSave = _amountMinor != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Expense'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
          // Amount field - hero element with subtle background
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: colorScheme.outlineVariant.withValues(alpha: 0.3),
              ),
            ),
            child: AmountField(
              key: _amountKey,
              currency: currency,
              focusNode: _amountFocusNode,
              maxMinorUnits: Expense.maxAmountMinor,
              onChangedMinor: (v) {
                if (_amountMinor != v) {
                  setState(() => _amountMinor = v);
                }
              },
            ),
          ),

          const SizedBox(height: 8),

          // Save button with enhanced styling
          SizedBox(
            width: double.infinity,
            height: 44,
            child: FilledButton(
              onPressed: canSave ? _save : null,
              style: FilledButton.styleFrom(
                disabledBackgroundColor: colorScheme.surfaceContainerHighest,
                disabledForegroundColor: colorScheme.onSurfaceVariant.withValues(alpha: 0.38),
              ),
              child: Text(
                'Save',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),

          const SizedBox(height: 8),

          // Visual divider
          Divider(
            color: colorScheme.outlineVariant.withValues(alpha: 0.3),
            height: 1,
          ),

          const SizedBox(height: 12),

          // Collapsible optional details section - fills space between content and ad
          Expanded(
            child: _OptionalDetailsSection(
              isExpanded: _optionalExpanded,
              onExpandedChanged: (expanded) {
                setState(() => _optionalExpanded = expanded);
              },
              categories: categories,
              categoryUsageCounts: categoryUsageCounts,
              selectedCategoryId: _selectedCategoryId,
              onCategoryChanged: (id) {
                setState(() => _selectedCategoryId = id);
              },
              locations: locationController.all,
              topUsedLocations: locationController.getTopUsed(limit: 10),
              locationSelection: _locationSelection,
              onLocationChanged: (selection) {
                setState(() => _locationSelection = selection);
              },
              selectedDate: _selectedDate,
              onSelectDate: _selectDate,
              currency: currency,
              onSelectCurrency: () => _selectCurrency(currency),
              currencyLocked: settings.lockedCurrencyCode != null,
              onCurrencyLockToggled: () {
                if (settings.lockedCurrencyCode != null) {
                  // Unlock
                  settings.setLockedCurrencyCode(null);
                } else {
                  // Lock to current currency
                  settings.setLockedCurrencyCode(currency.code);
                  // Set it as the selected currency for next entry
                  setState(() => _selectedCurrencyCode = currency.code);
                }
              },
              noteController: _noteController,
              colorScheme: colorScheme,
              theme: theme,
            ),
          ),

          // Banner ad at bottom
          const SafeArea(
            top: false,
            child: BannerAdWidget(),
          ),
        ],
      ),
    ),
      ),
    );
  }
}

/// Collapsible section for optional expense details.
class _OptionalDetailsSection extends StatelessWidget {
  final bool isExpanded;
  final ValueChanged<bool> onExpandedChanged;
  final List<ExpenseCategory> categories;
  final Map<String, int> categoryUsageCounts;
  final String? selectedCategoryId;
  final ValueChanged<String?> onCategoryChanged;
  final List<Location> locations;
  final List<Location> topUsedLocations;
  final LocationSelection locationSelection;
  final ValueChanged<LocationSelection> onLocationChanged;
  final DateTime selectedDate;
  final VoidCallback onSelectDate;
  final Currency currency;
  final VoidCallback onSelectCurrency;
  final bool currencyLocked;
  final VoidCallback onCurrencyLockToggled;
  final TextEditingController noteController;
  final ColorScheme colorScheme;
  final ThemeData theme;

  /// Description shown when collapsed.
  static const _collapsedDescription = 'Category, location, date, currency, notes';

  const _OptionalDetailsSection({
    required this.isExpanded,
    required this.onExpandedChanged,
    required this.categories,
    required this.categoryUsageCounts,
    required this.selectedCategoryId,
    required this.onCategoryChanged,
    required this.locations,
    required this.topUsedLocations,
    required this.locationSelection,
    required this.onLocationChanged,
    required this.selectedDate,
    required this.onSelectDate,
    required this.currency,
    required this.onSelectCurrency,
    required this.currencyLocked,
    required this.onCurrencyLockToggled,
    required this.noteController,
    required this.colorScheme,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header - tappable to expand/collapse
        InkWell(
          onTap: () => onExpandedChanged(!isExpanded),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                AnimatedRotation(
                  turns: isExpanded ? 0.25 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    Icons.keyboard_arrow_right,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Optional Details',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      AnimatedCrossFade(
                        firstChild: Text(
                          _collapsedDescription,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                          ),
                        ),
                        secondChild: const SizedBox.shrink(),
                        crossFadeState: isExpanded
                            ? CrossFadeState.showSecond
                            : CrossFadeState.showFirst,
                        duration: const Duration(milliseconds: 200),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // Expanded content - fills remaining space when expanded
        Expanded(
          child: AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: isExpanded
                ? Card(
                    margin: const EdgeInsets.only(top: 12),
                    elevation: 0,
                    color: colorScheme.surfaceContainerLow,
                    child: SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
                        child: _buildExpandedContent(context),
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ),
      ],
    );
  }

  Widget _buildExpandedContent(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final useGrid = screenWidth >= 360;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Category section
        Text(
          'Category',
          style: theme.textTheme.labelMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        CategoryAutocompleteField(
          categories: categories,
          usageCounts: categoryUsageCounts,
          selectedCategoryId: selectedCategoryId,
          onChanged: onCategoryChanged,
        ),

        const SizedBox(height: 10),

        // Location section
        Text(
          'Location',
          style: theme.textTheme.labelMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        LocationAutocompleteField(
          locations: locations,
          topUsed: topUsedLocations,
          selection: locationSelection,
          onChanged: onLocationChanged,
        ),

        const SizedBox(height: 10),

        // Date & Currency row (or column on narrow screens)
        if (useGrid)
          Row(
            children: [
              Expanded(child: _buildDatePicker()),
              const SizedBox(width: 10),
              Expanded(child: _buildCurrencyPicker()),
            ],
          )
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDatePicker(),
              const SizedBox(height: 8),
              _buildCurrencyPicker(),
            ],
          ),

        const SizedBox(height: 10),

        // Notes field with character counter
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              'Notes',
              style: theme.textTheme.labelMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: noteController,
              builder: (context, value, _) {
                return Text(
                  '${value.text.length}/500',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                    fontSize: 11,
                  ),
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 5),
        TextField(
          controller: noteController,
          decoration: const InputDecoration(
            hintText: 'Add a note (optional)',
            border: OutlineInputBorder(),
            isDense: true,
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          ),
          maxLines: 3,
          maxLength: 500,
          buildCounter: (context,
              {required currentLength, required isFocused, maxLength}) {
            return null;
          },
          textCapitalization: TextCapitalization.sentences,
          textInputAction: TextInputAction.newline,
        ),
      ],
    );
  }

  Widget _buildDatePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Date',
          style: theme.textTheme.labelMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        _ChipButton(
          onPressed: onSelectDate,
          icon: Icons.calendar_today,
          label: DateFormat.MMMd().format(selectedDate),
        ),
      ],
    );
  }

  Widget _buildCurrencyPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Currency',
          style: theme.textTheme.labelMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: _ChipButton(
                onPressed: onSelectCurrency,
                icon: Icons.currency_exchange,
                label: '${currency.symbol} ${currency.code}',
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onCurrencyLockToggled,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: currencyLocked
                      ? colorScheme.primary.withValues(alpha: 0.1)
                      : colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: currencyLocked
                        ? colorScheme.primary.withValues(alpha: 0.4)
                        : colorScheme.outlineVariant.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Icon(
                  currencyLocked ? Icons.lock : Icons.lock_open,
                  size: 20,
                  color: currencyLocked ? colorScheme.primary : colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Chip-styled button matching the design from transactions_filter_tab.dart.
///
/// Features:
/// - Light primary background (8% opacity) for visual distinction
/// - Primary border with subtle styling
/// - Smooth animations on interaction
/// - Icon and label support
class _ChipButton extends StatelessWidget {
  final VoidCallback onPressed;
  final IconData icon;
  final String label;

  const _ChipButton({
    required this.onPressed,
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return GestureDetector(
      onTap: onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: colorScheme.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: colorScheme.primary.withValues(alpha: 0.4),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: colorScheme.primary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: theme.textTheme.labelLarge?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
