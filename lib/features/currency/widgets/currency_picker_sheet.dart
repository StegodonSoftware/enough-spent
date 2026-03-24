import 'package:flutter/material.dart';

import '../models/currency.dart';
import 'currency_list.dart';

/// A bottom sheet for selecting a currency.
///
/// Use [showCurrencyPickerSheet] to display this sheet.
class CurrencyPickerSheet extends StatelessWidget {
  final String? selectedCode;
  final ValueChanged<Currency> onSelect;

  const CurrencyPickerSheet({
    super.key,
    this.selectedCode,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    // Use 70% of screen height for the sheet
    final maxHeight = MediaQuery.sizeOf(context).height * 0.7;

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHandle(context),
          _buildHeader(context),
          const Divider(height: 1),
          Expanded(
            child: CurrencyList(
              selectedCode: selectedCode,
              onSelect: onSelect,
              dense: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHandle(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 8),
      child: Container(
        width: 32,
        height: 4,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Select Currency',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

/// Shows a modal bottom sheet for currency selection.
///
/// Returns the selected [Currency], or null if dismissed.
/// Automatically marks selected currency as recently used.
Future<Currency?> showCurrencyPickerSheet(
  BuildContext context, {
  String? selectedCode,
}) {
  return showModalBottomSheet<Currency>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) => CurrencyPickerSheet(
      selectedCode: selectedCode,
      onSelect: (currency) {
        Navigator.pop(context, currency);
      },
    ),
  );
}
