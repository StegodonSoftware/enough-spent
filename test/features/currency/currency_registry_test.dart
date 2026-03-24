import 'package:flutter_test/flutter_test.dart';
import 'package:spending_tracker_app/features/currency/models/currency.dart';
import 'package:spending_tracker_app/features/currency/data/currency_registry.dart';

CurrencyRegistry _testRegistry() => CurrencyRegistry.forTesting({
      'USD': const Currency(
          code: 'USD', name: 'US Dollar', symbol: '\$', decimals: 2, numToBasic: 100),
      'EUR': const Currency(
          code: 'EUR', name: 'Euro', symbol: '\u20AC', decimals: 2, numToBasic: 100),
      'GBP': const Currency(
          code: 'GBP', name: 'British Pound', symbol: '\u00A3', decimals: 2, numToBasic: 100),
      'JPY': const Currency(
          code: 'JPY', name: 'Japanese Yen', symbol: '\u00A5', decimals: 0, numToBasic: 1),
      'AUD': const Currency(
          code: 'AUD', name: 'Australian Dollar', symbol: 'A\$', decimals: 2, numToBasic: 100),
      'CAD': const Currency(
          code: 'CAD', name: 'Canadian Dollar', symbol: 'CA\$', decimals: 2, numToBasic: 100),
      'ZAR': const Currency(
          code: 'ZAR', name: 'South African Rand', symbol: 'R', decimals: 2, numToBasic: 100),
    });

void main() {
  late CurrencyRegistry registry;

  setUp(() {
    registry = _testRegistry();
  });

  group('getByCode', () {
    test('returns matching currency', () {
      final eur = registry.getByCode('EUR');
      expect(eur.code, 'EUR');
      expect(eur.name, 'Euro');
    });

    test('returns USD fallback for unknown code', () {
      final result = registry.getByCode('XYZ');
      expect(result.code, 'USD');
    });

    test('returns static fallback when USD is also missing', () {
      final emptyRegistry = CurrencyRegistry.forTesting({
        'EUR': const Currency(
            code: 'EUR', name: 'Euro', symbol: '\u20AC', decimals: 2, numToBasic: 100),
      });
      final result = emptyRegistry.getByCode('XYZ');
      // Should return the hardcoded _fallback (USD)
      expect(result.code, 'USD');
    });
  });

  group('all', () {
    test('returns all currencies sorted by code', () {
      final list = registry.all;
      expect(list.length, 7);
      expect(list.first.code, 'AUD');
      expect(list.last.code, 'ZAR');
    });

    test('is sorted alphabetically', () {
      final codes = registry.all.map((c) => c.code).toList();
      final sorted = List<String>.from(codes)..sort();
      expect(codes, sorted);
    });
  });

  group('getAllSorted', () {
    test('popular currencies come first', () {
      final sorted = registry.getAllSorted();
      // Popular: USD, EUR, GBP, JPY, AUD, CAD — all present
      // Non-popular: ZAR
      final codes = sorted.map((c) => c.code).toList();

      // ZAR should be last (only non-popular)
      expect(codes.last, 'ZAR');

      // All popular ones should come before ZAR
      final zarIndex = codes.indexOf('ZAR');
      expect(zarIndex, 6); // index 6 = last of 7
    });

    test('popular currencies sorted alphabetically among themselves', () {
      final sorted = registry.getAllSorted();
      final popularCodes =
          sorted.where((c) => ['USD', 'EUR', 'GBP', 'JPY', 'AUD', 'CAD'].contains(c.code))
              .map((c) => c.code)
              .toList();
      final expectedOrder = List<String>.from(popularCodes)..sort();
      expect(popularCodes, expectedOrder);
    });
  });

  group('commonCurrencies', () {
    test('returns popular currencies in order', () {
      final common = registry.commonCurrencies;
      // _popular = ['USD', 'EUR', 'GBP', 'JPY', 'AUD', 'CAD']
      expect(common.length, 6);
      expect(common[0].code, 'USD');
      expect(common[1].code, 'EUR');
      expect(common[5].code, 'CAD');
    });

    test('uses fallback for missing popular currency', () {
      // Registry without GBP
      final partial = CurrencyRegistry.forTesting({
        'USD': const Currency(
            code: 'USD', name: 'US Dollar', symbol: '\$', decimals: 2, numToBasic: 100),
        'EUR': const Currency(
            code: 'EUR', name: 'Euro', symbol: '\u20AC', decimals: 2, numToBasic: 100),
      });

      final common = partial.commonCurrencies;
      // GBP is missing, so getByCode falls back to USD
      expect(common.length, 6);
      // GBP slot (index 2) should be USD fallback
      expect(common[2].code, 'USD');
    });
  });
}
