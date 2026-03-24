import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/currency.dart';

class CurrencyRegistry {
  static const _popular = ['USD', 'EUR', 'GBP', 'JPY', 'AUD', 'CAD'];

  /// Fallback currency used when lookup fails.
  static const _fallback = Currency(
    code: 'USD',
    name: 'US Dollar',
    symbol: '\$',
    decimals: 2,
    numToBasic: 100,
  );

  final Map<String, Currency> _currencies;
  CurrencyRegistry._(this._currencies);

  /// Test-only constructor for creating a registry with known currencies.
  @visibleForTesting
  CurrencyRegistry.forTesting(this._currencies);

  static Future<CurrencyRegistry> load() async {
    try {
      final raw = await rootBundle.loadString('assets/data/currencies.json');
      final decoded = json.decode(raw) as Map<String, dynamic>;

      final currencies = decoded.map(
        (code, data) => MapEntry(code, Currency.fromJson(code, data as Map<String, dynamic>)),
      );

      return CurrencyRegistry._(currencies);
    } catch (e, stack) {
      // Log error in debug mode, return fallback registry in production
      if (kDebugMode) {
        debugPrint('CurrencyRegistry.load() failed: $e\n$stack');
        rethrow;
      }
      // Production: return minimal registry with fallback
      return CurrencyRegistry._({_fallback.code: _fallback});
    }
  }

  /// Returns the currency for the given code, or USD if not found.
  Currency getByCode(String code) {
    final currency = _currencies[code];
    if (currency != null) return currency;

    // Log missing currency in debug mode
    assert(() {
      debugPrint('CurrencyRegistry: unknown currency code "$code", using USD fallback');
      return true;
    }());

    return _currencies['USD'] ?? _fallback;
  }

  List<Currency> get all {
    final list = _currencies.values.toList();
    list.sort((a, b) => a.code.compareTo(b.code));
    return list;
  }

  /// Returns all currencies sorted with popular ones first.
  List<Currency> getAllSorted() {
    final all = _currencies.values.toList();

    all.sort((a, b) {
      final aPop = _popular.contains(a.code);
      final bPop = _popular.contains(b.code);

      if (aPop && !bPop) return -1;
      if (!aPop && bPop) return 1;

      return a.code.compareTo(b.code);
    });

    return all;
  }

  List<Currency> get commonCurrencies {
    return _popular.map(getByCode).toList();
  }
}
