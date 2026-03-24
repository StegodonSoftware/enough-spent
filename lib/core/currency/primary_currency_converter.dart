import 'package:flutter/foundation.dart';

import '../../features/expenses/data/expense_repository.dart';
import '../../features/expenses/models/expense.dart';
import '../../features/settings/data/settings_repository.dart';
import 'currency_service.dart';

/// Handles conversion of all expenses to a new primary currency.
/// When the primary currency changes, all historical expenses need to be
/// re-converted using the current exchange rates.
class PrimaryCurrencyConverter {
  final ExpenseRepository _expenseRepository;
  final CurrencyService _currencyService;
  final SettingsRepository _settingsRepository;
  VoidCallback? onExpensesModified;

  PrimaryCurrencyConverter({
    required ExpenseRepository expenseRepository,
    required CurrencyService currencyService,
    required SettingsRepository settingsRepository,
    this.onExpensesModified,
  })  : _expenseRepository = expenseRepository,
        _currencyService = currencyService,
        _settingsRepository = settingsRepository;

  /// Convert all expenses to a new primary currency.
  ///
  /// Returns a record with [converted] (successfully converted) and [total]
  /// (all expenses attempted). If [converted] < [total], some expenses could
  /// not be converted due to missing exchange rates for their currency.
  ///
  /// Throws if the new currency is not supported by the exchange rates.
  ({int converted, int total}) convertAllExpensesToPrimaryCurrency(
    String newPrimaryCurrency,
  ) {
    if (!_currencyService.isSupported(newPrimaryCurrency)) {
      throw UnsupportedError(
        'Currency $newPrimaryCurrency is not supported',
      );
    }

    // Set safety flag so we can detect interrupted conversions on next startup
    _settingsRepository.setConversionInProgress(true);

    final allExpenses = _expenseRepository.getAll();
    final convertedExpenses = <Expense>[];
    int convertedCount = 0;

    for (final expense in allExpenses) {
      final converted = _convertExpenseToNewPrimaryCurrency(
        expense,
        newPrimaryCurrency,
      );
      if (converted != null) {
        convertedExpenses.add(converted);
        convertedCount++;
      }
    }

    if (convertedExpenses.isNotEmpty) {
      _expenseRepository.saveBatch(convertedExpenses);
    }

    // Clear safety flag on success
    _settingsRepository.setConversionInProgress(false);

    // Notify that expense data was modified outside ExpenseController
    onExpensesModified?.call();

    return (converted: convertedCount, total: allExpenses.length);
  }

  /// Convert a single expense to the new primary currency.
  /// Returns null if conversion is not possible.
  Expense? _convertExpenseToNewPrimaryCurrency(
    Expense expense,
    String newPrimaryCurrency,
  ) {
    // Use CurrencyService.convert() which handles numToBasic scaling correctly
    final amountInNewPrimary = _currencyService.convert(
      amountMinor: expense.amountMinor,
      from: expense.currencyCode,
      to: newPrimaryCurrency,
    );

    if (amountInNewPrimary == null) {
      if (kDebugMode) {
        debugPrint(
          'PrimaryCurrencyConverter: Failed to convert '
          '${expense.currencyCode} to $newPrimaryCurrency',
        );
      }
      return null;
    }

    // Calculate the display rate: 1 [source major] = X [primary major]
    final rateToUsd = _currencyService.getRateToUsd(expense.currencyCode);
    final rateFromUsd = _currencyService.getRateFromUsd(newPrimaryCurrency);
    final rateToPrimary = (rateToUsd != null && rateFromUsd != null)
        ? rateToUsd * rateFromUsd
        : null;

    return expense.copyWith(
      amountInPrimary: amountInNewPrimary,
      primaryCurrencyCode: newPrimaryCurrency,
      rateToPrimary: rateToPrimary,
      conversionDate: _currencyService.ratesTimestamp,
    );
  }
}
