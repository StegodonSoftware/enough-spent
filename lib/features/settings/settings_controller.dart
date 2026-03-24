import 'package:flutter/material.dart';

import '../../core/currency/primary_currency_converter.dart';
import 'data/settings_repository.dart';

class SettingsController extends ChangeNotifier {
  final SettingsRepository _repository;
  final PrimaryCurrencyConverter? _currencyConverter;
  static const int _maxRecent = 5;

  SettingsController(
    this._repository, {
    PrimaryCurrencyConverter? currencyConverter,
  }) : _currencyConverter = currencyConverter {
    _recentCurrencies = _repository.getRecentCurrencies();
    // Ensure primary currency is always in recents
    final primary = primaryCurrency;
    if (!_recentCurrencies.contains(primary)) {
      _recentCurrencies.insert(0, primary);
      if (_recentCurrencies.length > _maxRecent) {
        _recentCurrencies = _recentCurrencies.take(_maxRecent).toList();
      }
      _repository.saveRecentCurrencies(_recentCurrencies);
    }

    // Recover from interrupted currency conversion
    if (_repository.getConversionInProgress()) {
      debugPrint('SettingsController: Detected interrupted conversion, re-running...');
      if (_currencyConverter != null) {
        try {
          _currencyConverter.convertAllExpensesToPrimaryCurrency(primary);
        } catch (e) {
          debugPrint('SettingsController: Recovery conversion failed: $e');
        }
      }
    }
  }

  /// Primary currency is used for:
  /// - Default currency when creating new expenses
  /// - Display currency for converted amounts in lists and insights
  String get primaryCurrency => _repository.getPrimaryCurrency();

  int get firstDayOfWeek => _repository.getFirstDayOfWeek();

  bool get isOnboarded => _repository.isOnboarded();

  /// Locked currency code for travel mode (null = no lock)
  String? get lockedCurrencyCode => _repository.getLockedCurrencyCode();

  List<String> _recentCurrencies = [];

  List<String> get recentCurrencies => List.unmodifiable(_recentCurrencies);

  void setPrimaryCurrency(String code) {
    _repository.setPrimaryCurrency(code);
    markCurrencyUsed(code);
  }

  /// Change the primary currency and convert all expenses to the new currency.
  ///
  /// Returns a record with the number of [converted] expenses and the [total]
  /// attempted. If no converter is available, returns zeros.
  ///
  /// Throws if the conversion fails — the primary currency setting is only
  /// saved when conversion succeeds, keeping data in a consistent state.
  ({int converted, int total}) setPrimaryCurrencyWithConversion(String newCode) {
    var result = (converted: 0, total: 0);

    if (_currencyConverter != null) {
      // Exceptions propagate intentionally — setting is only saved on success
      result = _currencyConverter.convertAllExpensesToPrimaryCurrency(newCode);
    }

    _repository.setPrimaryCurrency(newCode);
    markCurrencyUsed(newCode);

    return result;
  }

  void setFirstDayOfWeek(int weekday) {
    _repository.setFirstDayOfWeek(weekday);
    notifyListeners();
  }

  void completeOnboarding() {
    _repository.setOnboarded(true);
    notifyListeners();
  }

  void markCurrencyUsed(String code) {
    _recentCurrencies.remove(code);
    _recentCurrencies.insert(0, code);

    if (_recentCurrencies.length > _maxRecent) {
      _recentCurrencies = _recentCurrencies.take(_maxRecent).toList();
    }

    _repository.saveRecentCurrencies(_recentCurrencies);
    notifyListeners();
  }

  void setLockedCurrencyCode(String? currencyCode) {
    _repository.setLockedCurrencyCode(currencyCode);
    notifyListeners();
  }
}
