import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

import '../../features/currency/data/currency_registry.dart';
import 'currency_rate_provider.dart';
import 'models/exchange_rates.dart';

/// Result of a currency conversion operation.
class ConversionResult {
  /// The converted amount in minor units (e.g., cents).
  final int amount;

  /// The rate used for conversion (from original currency to USD).
  final double rateToUsd;

  /// Whether the conversion used current rates (vs. stale/bundled).
  final bool usedCurrentRates;

  const ConversionResult({
    required this.amount,
    required this.rateToUsd,
    required this.usedCurrentRates,
  });
}

/// Service for currency conversion operations.
/// Uses USD as the canonical intermediate currency for all conversions.
class CurrencyService extends ChangeNotifier {
  ExchangeRates _rates;
  final CurrencyRegistry _registry;
  final Box _settingsBox;

  CurrencyService(this._rates, this._registry, this._settingsBox);

  /// Current exchange rates.
  ExchangeRates get rates => _rates;

  /// Update the exchange rates (e.g., after fetching fresh rates).
  void updateRates(ExchangeRates newRates) {
    _rates = newRates;
    notifyListeners();
  }

  /// Fetch fresh rates from the remote endpoint and update if successful.
  /// Returns true on success, false if the remote fetch failed (e.g. offline).
  Future<bool> refreshRates() async {
    final fresh = await CurrencyRateProvider.refreshRates(_settingsBox);
    if (fresh != null) {
      if (kDebugMode) {
        debugPrint('CurrencyService: User-triggered refresh succeeded (${fresh.currencyCount} currencies)');
      }
      updateRates(fresh);
      return true;
    }
    if (kDebugMode) {
      debugPrint('CurrencyService: User-triggered refresh failed — see CurrencyRateProvider logs above');
    }
    return false;
  }

  /// Returns true if current rates are stale (older than 24 hours).
  bool get hasStaleRates => _rates.isStale;

  /// Timestamp of current rates.
  DateTime get ratesTimestamp => _rates.timestamp;

  /// Get the rate from a currency to USD.
  /// Returns null if the currency is not supported.
  double? getRateToUsd(String currencyCode) {
    if (currencyCode == 'USD') return 1.0;
    final rate = _rates.getRate(currencyCode);
    if (rate == null || rate == 0) return null;
    // rates are stored as "1 USD = X currency"
    // so rate to USD is 1/X
    return 1.0 / rate;
  }

  /// Get the rate from USD to a currency.
  /// Returns null if the currency is not supported.
  double? getRateFromUsd(String currencyCode) {
    if (currencyCode == 'USD') return 1.0;
    return _rates.getRate(currencyCode);
  }

  /// Convert an amount from one currency to another.
  ///
  /// [amountMinor] - Amount in minor units (e.g., cents for USD, whole units for JPY)
  /// [from] - Source currency code
  /// [to] - Target currency code
  ///
  /// Returns the converted amount in target currency minor units,
  /// or null if either currency is not supported.
  int? convert({
    required int amountMinor,
    required String from,
    required String to,
  }) {
    if (from == to) return amountMinor;

    final fromRate = getRateToUsd(from);
    final toRate = getRateFromUsd(to);

    if (fromRate == null || toRate == null) return null;

    // Rates work in major units (1 JPY = 0.0067 USD).
    // Scale by numToBasic ratio to convert between minor unit systems.
    final fromNumToBasic = _registry.getByCode(from).numToBasic;
    final toNumToBasic = _registry.getByCode(to).numToBasic;

    // Convert: source minor → source major → USD major → target major → target minor
    final targetAmount = amountMinor * fromRate * toRate * toNumToBasic / fromNumToBasic;

    return targetAmount.round();
  }

  /// Convert an amount to USD and return both the amount and rate used.
  /// This is used when saving expenses to store the historical rate.
  ///
  /// Returns null if the currency is not supported.
  ConversionResult? convertToUsd({
    required int amountMinor,
    required String from,
  }) {
    if (from == 'USD') {
      return ConversionResult(
        amount: amountMinor,
        rateToUsd: 1.0,
        usedCurrentRates: !_rates.isStale,
      );
    }

    final rateToUsd = getRateToUsd(from);
    if (rateToUsd == null) return null;

    // Scale between minor unit systems (e.g., JPY numToBasic=1 → USD numToBasic=100)
    final fromNumToBasic = _registry.getByCode(from).numToBasic;
    const usdNumToBasic = 100;
    final usdAmount = (amountMinor * rateToUsd * usdNumToBasic / fromNumToBasic).round();

    return ConversionResult(
      amount: usdAmount,
      rateToUsd: rateToUsd,
      usedCurrentRates: !_rates.isStale,
    );
  }

  /// Convert an amount from USD to the target currency.
  /// Used for display when target is the user's primary currency.
  ///
  /// [amountInUsd] - Amount in USD minor units (cents)
  /// [to] - Target currency code
  ///
  /// Returns null if the currency is not supported.
  int? convertFromUsd({
    required int amountInUsd,
    required String to,
  }) {
    if (to == 'USD') return amountInUsd;

    final rate = getRateFromUsd(to);
    if (rate == null) return null;

    // Scale between minor unit systems (USD numToBasic=100 → target numToBasic)
    final toNumToBasic = _registry.getByCode(to).numToBasic;
    const usdNumToBasic = 100;

    return (amountInUsd * rate * toNumToBasic / usdNumToBasic).round();
  }

  /// Check if a currency is supported for conversion.
  bool isSupported(String currencyCode) {
    return currencyCode == 'USD' || _rates.hasRate(currencyCode);
  }

  /// Get debug information about current exchange rates.
  /// Returns a map with source, timestamp, age, stale status, and currency count.
  Map<String, dynamic> getDebugInfo() {
    return {
      'source': _rates.source ?? 'unknown',
      'timestamp': _rates.timestamp,
      'ageInHours': _rates.age.inHours,
      'isStale': _rates.isStale,
      'currencyCount': _rates.currencyCount,
      'base': _rates.base,
    };
  }
}
