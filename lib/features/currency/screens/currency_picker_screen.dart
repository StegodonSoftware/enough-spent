import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/toast/toast.dart';
import '../widgets/currency_list.dart';
import '../../settings/settings_controller.dart';

/// Full-screen currency picker for settings.
///
/// Updates the primary currency in settings when a currency is selected.
/// Shows a warning dialog about currency conversion using current rates.
class CurrencyPickerScreen extends StatelessWidget {
  const CurrencyPickerScreen({super.key});

  Future<void> _showCurrencyChangeWarning(
    BuildContext context,
    String newCurrencyCode,
    String currentCurrencyCode,
  ) async {
    if (newCurrencyCode == currentCurrencyCode) {
      Navigator.pop(context);
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Change Primary Currency?'),
        content: const Text(
          'Your historical expenses will be converted using the most recent exchange rates. This may result in different total values than when the expenses were originally logged. The original transaction amounts in their original currencies are preserved.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Convert & Change'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    // Show non-dismissible loading dialog while conversion runs
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const PopScope(
        canPop: false,
        child: Dialog(
          child: Padding(
            padding: EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Converting expenses...'),
              ],
            ),
          ),
        ),
      ),
    );

    // Yield so the loading dialog paints before the synchronous conversion runs
    await WidgetsBinding.instance.endOfFrame;

    if (!context.mounted) return;

    ({int converted, int total}) result;
    try {
      result = context
          .read<SettingsController>()
          .setPrimaryCurrencyWithConversion(newCurrencyCode);
    } catch (e) {
      // Conversion failed — setting was NOT saved, so state remains consistent.
      // Dismiss the loading dialog but stay on the picker screen.
      if (!context.mounted) return;
      Navigator.pop(context); // Dismiss loading dialog
      Toast.error(context, 'Failed to change currency. Please try again.');
      return;
    }

    if (!context.mounted) return;
    Navigator.pop(context); // Dismiss loading dialog
    Navigator.pop(context); // Close picker screen

    // Toast is inserted into the root overlay so it persists after the pop
    // and appears on the settings screen beneath.
    if (!context.mounted) return;
    if (result.total == 0) {
      Toast.success(context, 'Primary currency set to $newCurrencyCode');
    } else if (result.converted == result.total) {
      final n = result.converted;
      Toast.success(
        context,
        '$n ${n == 1 ? 'expense' : 'expenses'} converted to $newCurrencyCode',
      );
    } else {
      Toast.warning(
        context,
        'Converted ${result.converted} of ${result.total} expenses to $newCurrencyCode',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>();

    return Scaffold(
      appBar: AppBar(title: const Text('Primary Currency')),
      body: CurrencyList(
        selectedCode: settings.primaryCurrency,
        onSelect: (currency) {
          _showCurrencyChangeWarning(
            context,
            currency.code,
            settings.primaryCurrency,
          );
        },
      ),
    );
  }
}
