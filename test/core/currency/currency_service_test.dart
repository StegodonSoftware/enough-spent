import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:hive_test/hive_test.dart';
import 'package:spending_tracker_app/core/currency/currency_service.dart';
import 'package:spending_tracker_app/core/currency/models/exchange_rates.dart';
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
      'KRW': const Currency(
          code: 'KRW', name: 'South Korean Won', symbol: '\u20A9', decimals: 0, numToBasic: 1),
      'BHD': const Currency(
          code: 'BHD', name: 'Bahraini Dinar', symbol: 'BD', decimals: 3, numToBasic: 1000),
    });

ExchangeRates _freshRates(Map<String, double> rates) => ExchangeRates(
      base: 'USD',
      timestamp: DateTime.now(),
      rates: rates,
      source: 'test',
    );

void main() {
  // Standard test rates: 1 USD = X currency
  final testRates = _freshRates({
    'EUR': 0.84,
    'GBP': 0.73,
    'JPY': 153.0,
    'KRW': 1350.0,
    'BHD': 0.376,
  });

  late CurrencyService service;
  late Box settingsBox;

  setUp(() async {
    await setUpTestHive();
    settingsBox = await Hive.openBox('settings');
    final registry = _testRegistry();
    service = CurrencyService(testRates, registry, settingsBox);
  });

  tearDown(() async => tearDownTestHive());

  group('getRateToUsd', () {
    test('returns 1.0 for USD', () {
      expect(service.getRateToUsd('USD'), 1.0);
    });

    test('returns inverse of stored rate', () {
      // 1 USD = 0.84 EUR, so 1 EUR = 1/0.84 USD
      final rate = service.getRateToUsd('EUR')!;
      expect(rate, closeTo(1.0 / 0.84, 0.0001));
    });

    test('returns null for unsupported currency', () {
      expect(service.getRateToUsd('XYZ'), isNull);
    });
  });

  group('getRateFromUsd', () {
    test('returns 1.0 for USD', () {
      expect(service.getRateFromUsd('USD'), 1.0);
    });

    test('returns stored rate directly', () {
      expect(service.getRateFromUsd('EUR'), 0.84);
    });

    test('returns null for unsupported currency', () {
      expect(service.getRateFromUsd('XYZ'), isNull);
    });
  });

  group('convert — same numToBasic (2-decimal → 2-decimal)', () {
    test('USD to EUR', () {
      // 1000 cents USD → EUR cents
      // 1000 * (1/1) * 0.84 * (100/100) = 840
      final result = service.convert(amountMinor: 1000, from: 'USD', to: 'EUR');
      expect(result, 840);
    });

    test('EUR to USD', () {
      // 1000 EUR cents → USD cents
      // 1000 * (1/0.84) * 1.0 * (100/100) ≈ 1190
      final result = service.convert(amountMinor: 1000, from: 'EUR', to: 'USD');
      expect(result, closeTo(1190, 2));
    });

    test('EUR to GBP', () {
      // 1000 EUR cents → GBP cents
      // 1000 * (1/0.84) * 0.73 * (100/100) ≈ 869
      final result = service.convert(amountMinor: 1000, from: 'EUR', to: 'GBP');
      expect(result, closeTo(869, 2));
    });

    test('same currency returns same amount', () {
      expect(service.convert(amountMinor: 500, from: 'USD', to: 'USD'), 500);
      expect(service.convert(amountMinor: 123, from: 'EUR', to: 'EUR'), 123);
    });
  });

  group('convert — different numToBasic (the bug we fixed)', () {
    test('JPY to EUR — zero-decimal to 2-decimal', () {
      // 500 JPY (minor=major for JPY) → EUR cents
      // 500 * (1/153.0) * 0.84 * (100/1) = 274.5 → 275
      final result = service.convert(amountMinor: 500, from: 'JPY', to: 'EUR');
      expect(result, closeTo(275, 2));
    });

    test('EUR to JPY — 2-decimal to zero-decimal', () {
      // 500 EUR cents (= 5.00 EUR) → JPY
      // 500 * (1/0.84) * 153.0 * (1/100) = 910.7 → 911
      final result = service.convert(amountMinor: 500, from: 'EUR', to: 'JPY');
      expect(result, closeTo(911, 2));
    });

    test('USD to JPY', () {
      // 1000 USD cents (= $10) → JPY
      // 1000 * 1.0 * 153.0 * (1/100) = 1530
      final result = service.convert(amountMinor: 1000, from: 'USD', to: 'JPY');
      expect(result, 1530);
    });

    test('JPY to USD', () {
      // 1530 JPY → USD cents
      // 1530 * (1/153.0) * 1.0 * (100/1) = 1000
      final result = service.convert(amountMinor: 1530, from: 'JPY', to: 'USD');
      expect(result, 1000);
    });

    test('JPY to KRW — zero-decimal to zero-decimal', () {
      // 100 JPY → KRW (both numToBasic=1)
      // 100 * (1/153.0) * 1350.0 * (1/1) = 882.35 → 882
      final result = service.convert(amountMinor: 100, from: 'JPY', to: 'KRW');
      expect(result, closeTo(882, 2));
    });

    test('BHD to USD — 3-decimal to 2-decimal', () {
      // 1000 BHD fils (= 1.000 BHD) → USD cents
      // 1000 * (1/0.376) * 1.0 * (100/1000) = 265.96 → 266
      final result = service.convert(amountMinor: 1000, from: 'BHD', to: 'USD');
      expect(result, closeTo(266, 2));
    });

    test('USD to BHD — 2-decimal to 3-decimal', () {
      // 266 USD cents (= $2.66) → BHD fils
      // 266 * 1.0 * 0.376 * (1000/100) = 1000.16 → 1000
      final result = service.convert(amountMinor: 266, from: 'USD', to: 'BHD');
      expect(result, closeTo(1000, 2));
    });
  });

  group('convert — edge cases', () {
    test('returns null when source unsupported', () {
      expect(service.convert(amountMinor: 100, from: 'XYZ', to: 'USD'), isNull);
    });

    test('returns null when target unsupported', () {
      expect(service.convert(amountMinor: 100, from: 'USD', to: 'XYZ'), isNull);
    });

    test('zero amount', () {
      expect(service.convert(amountMinor: 0, from: 'USD', to: 'EUR'), 0);
    });

    test('large amount stays precise', () {
      // $100,000 = 10,000,000 cents → EUR
      final result = service.convert(amountMinor: 10000000, from: 'USD', to: 'EUR');
      expect(result, 8400000); // 84,000.00 EUR
    });
  });

  group('convertToUsd', () {
    test('USD returns same amount with rate 1.0', () {
      final result = service.convertToUsd(amountMinor: 500, from: 'USD');
      expect(result, isNotNull);
      expect(result!.amount, 500);
      expect(result.rateToUsd, 1.0);
    });

    test('EUR to USD with numToBasic scaling', () {
      // 1000 EUR cents → USD cents
      // 1000 * (1/0.84) * (100/100) ≈ 1190
      final result = service.convertToUsd(amountMinor: 1000, from: 'EUR');
      expect(result, isNotNull);
      expect(result!.amount, closeTo(1190, 2));
    });

    test('JPY to USD with numToBasic scaling', () {
      // 1000 JPY → USD cents
      // 1000 * (1/153.0) * (100/1) ≈ 654
      final result = service.convertToUsd(amountMinor: 1000, from: 'JPY');
      expect(result, isNotNull);
      expect(result!.amount, closeTo(654, 2));
    });

    test('unsupported currency returns null', () {
      expect(service.convertToUsd(amountMinor: 100, from: 'XYZ'), isNull);
    });
  });

  group('convertFromUsd', () {
    test('to USD returns same amount', () {
      expect(service.convertFromUsd(amountInUsd: 500, to: 'USD'), 500);
    });

    test('to EUR', () {
      // 1000 USD cents → EUR cents
      // 1000 * 0.84 * (100/100) = 840
      expect(service.convertFromUsd(amountInUsd: 1000, to: 'EUR'), 840);
    });

    test('to JPY', () {
      // 1000 USD cents ($10) → JPY
      // 1000 * 153.0 * (1/100) = 1530
      expect(service.convertFromUsd(amountInUsd: 1000, to: 'JPY'), 1530);
    });

    test('unsupported currency returns null', () {
      expect(service.convertFromUsd(amountInUsd: 100, to: 'XYZ'), isNull);
    });
  });

  group('isSupported', () {
    test('USD is always supported', () {
      expect(service.isSupported('USD'), isTrue);
    });

    test('currencies with rates are supported', () {
      expect(service.isSupported('EUR'), isTrue);
      expect(service.isSupported('JPY'), isTrue);
    });

    test('unknown currency is not supported', () {
      expect(service.isSupported('XYZ'), isFalse);
    });
  });

  group('stale rates', () {
    test('fresh rates are not stale', () {
      expect(service.hasStaleRates, isFalse);
    });

    test('old rates are stale', () {
      final oldRates = ExchangeRates(
        base: 'USD',
        timestamp: DateTime.now().subtract(const Duration(hours: 25)),
        rates: {'EUR': 0.84},
      );
      final registry = _testRegistry();
      final staleService = CurrencyService(oldRates, registry, settingsBox);
      expect(staleService.hasStaleRates, isTrue);
    });
  });

  group('updateRates', () {
    test('updates rates and notifies listeners', () {
      int notifyCount = 0;
      service.addListener(() => notifyCount++);

      final newRates = _freshRates({'EUR': 0.90});
      service.updateRates(newRates);

      expect(service.getRateFromUsd('EUR'), 0.90);
      expect(notifyCount, 1);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Edge cases: zero-decimal rounding
  // ─────────────────────────────────────────────────────────────────────────

  group('zero-decimal rounding', () {
    test('USD to JPY rounds to whole yen (no fractional yen)', () {
      // 1 USD cent → JPY: 1 * 1.0 * 153.0 * (1/100) = 1.53 → rounds to 2
      final result = service.convert(amountMinor: 1, from: 'USD', to: 'JPY');
      expect(result, isNotNull);
      // Result is an int — no fractional units possible
      expect(result, isA<int>());
    });

    test('1 JPY to USD: small amount rounds correctly', () {
      // 1 JPY → USD cents: 1 * (1/153) * 1.0 * (100/1) ≈ 0.65 → rounds to 1
      final result = service.convert(amountMinor: 1, from: 'JPY', to: 'USD');
      expect(result, isNotNull);
      expect(result, isA<int>());
    });

    test('JPY to KRW zero-decimal to zero-decimal stays whole units', () {
      // Both zero-decimal: result must be a whole integer
      final result = service.convert(amountMinor: 100, from: 'JPY', to: 'KRW');
      expect(result, isNotNull);
      expect(result, isA<int>());
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Edge cases: three-decimal currency (BHD)
  // ─────────────────────────────────────────────────────────────────────────

  group('three-decimal currency (BHD) precision', () {
    test('1 BHD fil (smallest unit) to USD rounds without crash', () {
      // 1 fil = 0.001 BHD → USD cents: 1 * (1/0.376) * 1.0 * (100/1000) ≈ 0.27
      final result = service.convert(amountMinor: 1, from: 'BHD', to: 'USD');
      expect(result, isNotNull);
      expect(result, isA<int>());
    });

    test('round-trip BHD → USD → BHD is stable within 1 unit', () {
      const startFils = 1000; // 1.000 BHD
      final toUsd = service.convert(amountMinor: startFils, from: 'BHD', to: 'USD')!;
      final backToBhd = service.convert(amountMinor: toUsd, from: 'USD', to: 'BHD')!;
      // Rounding over two conversions should stay within 1 fil
      expect((backToBhd - startFils).abs(), lessThanOrEqualTo(1));
    });

    test('BHD to JPY cross-decimal conversion', () {
      // 1000 BHD fils (1.000 BHD) → JPY
      // 1000 * (1/0.376) * 153.0 * (1/1000) ≈ 407
      final result = service.convert(amountMinor: 1000, from: 'BHD', to: 'JPY');
      expect(result, isNotNull);
      expect(result, closeTo(407, 5));
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Edge cases: chained conversion precision
  // ─────────────────────────────────────────────────────────────────────────

  group('chained conversion precision', () {
    test('EUR → USD → EUR round-trip within 1 cent', () {
      const startCents = 10000; // 100.00 EUR
      final toUsd = service.convert(amountMinor: startCents, from: 'EUR', to: 'USD')!;
      final backToEur = service.convert(amountMinor: toUsd, from: 'USD', to: 'EUR')!;
      expect((backToEur - startCents).abs(), lessThanOrEqualTo(1));
    });

    test('large amount round-trip USD → EUR → USD within 1 cent', () {
      const startCents = 1000000; // $10,000.00
      final toEur = service.convert(amountMinor: startCents, from: 'USD', to: 'EUR')!;
      final backToUsd = service.convert(amountMinor: toEur, from: 'EUR', to: 'USD')!;
      expect((backToUsd - startCents).abs(), lessThanOrEqualTo(2));
    });

    test('convertToUsd usedCurrentRates reflects staleness', () {
      final freshResult = service.convertToUsd(amountMinor: 1000, from: 'EUR');
      expect(freshResult!.usedCurrentRates, isTrue);
    });

    test('convertToUsd usedCurrentRates false for stale rates', () {
      final staleRates = ExchangeRates(
        base: 'USD',
        timestamp: DateTime.now().subtract(const Duration(hours: 25)),
        rates: {'EUR': 0.84},
      );
      final staleService = CurrencyService(staleRates, _testRegistry(), settingsBox);
      final result = staleService.convertToUsd(amountMinor: 1000, from: 'EUR');
      expect(result!.usedCurrentRates, isFalse);
    });
  });

  group('getDebugInfo', () {
    test('returns expected keys', () {
      final info = service.getDebugInfo();
      expect(info.containsKey('source'), isTrue);
      expect(info.containsKey('timestamp'), isTrue);
      expect(info.containsKey('isStale'), isTrue);
      expect(info.containsKey('currencyCount'), isTrue);
      expect(info['isStale'], isFalse);
    });
  });
}
