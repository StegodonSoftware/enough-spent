import 'package:flutter_test/flutter_test.dart';
import 'package:spending_tracker_app/core/currency/models/exchange_rates.dart';

void main() {
  group('ExchangeRates', () {
    test('getRate returns stored rate', () {
      final rates = ExchangeRates(
        base: 'USD',
        timestamp: DateTime.now(),
        rates: {'EUR': 0.84, 'JPY': 153.0},
      );
      expect(rates.getRate('EUR'), 0.84);
      expect(rates.getRate('JPY'), 153.0);
    });

    test('getRate returns null for missing currency', () {
      final rates = ExchangeRates(
        base: 'USD',
        timestamp: DateTime.now(),
        rates: {'EUR': 0.84},
      );
      expect(rates.getRate('GBP'), isNull);
    });

    test('hasRate', () {
      final rates = ExchangeRates(
        base: 'USD',
        timestamp: DateTime.now(),
        rates: {'EUR': 0.84},
      );
      expect(rates.hasRate('EUR'), isTrue);
      expect(rates.hasRate('GBP'), isFalse);
    });

    test('currencyCount', () {
      final rates = ExchangeRates(
        base: 'USD',
        timestamp: DateTime.now(),
        rates: {'EUR': 0.84, 'JPY': 153.0, 'GBP': 0.73},
      );
      expect(rates.currencyCount, 3);
    });

    test('isStale with fresh rates', () {
      final rates = ExchangeRates(
        base: 'USD',
        timestamp: DateTime.now(),
        rates: {},
      );
      expect(rates.isStale, isFalse);
    });

    test('isStale with old rates', () {
      final rates = ExchangeRates(
        base: 'USD',
        timestamp: DateTime.now().subtract(const Duration(hours: 25)),
        rates: {},
      );
      expect(rates.isStale, isTrue);
    });

    test('isOlderThan', () {
      final rates = ExchangeRates(
        base: 'USD',
        timestamp: DateTime.now().subtract(const Duration(hours: 5)),
        rates: {},
      );
      expect(rates.isOlderThan(const Duration(hours: 4)), isTrue);
      expect(rates.isOlderThan(const Duration(hours: 6)), isFalse);
    });
  });

  group('fromJson / toJson', () {
    test('round-trips correctly', () {
      final original = ExchangeRates(
        base: 'USD',
        timestamp: DateTime.utc(2025, 6, 15, 12, 0),
        rates: {'EUR': 0.84, 'JPY': 153.0},
        source: 'test',
      );
      final json = original.toJson();
      final restored = ExchangeRates.fromJson(json);

      expect(restored.base, 'USD');
      expect(restored.rates['EUR'], 0.84);
      expect(restored.rates['JPY'], 153.0);
      expect(restored.source, 'test');
    });

    test('source is optional in json', () {
      final json = {
        'base': 'USD',
        'timestamp': '2025-06-15T12:00:00.000Z',
        'rates': {'EUR': 0.84},
      };
      final rates = ExchangeRates.fromJson(json);
      expect(rates.source, isNull);
    });

    test('source excluded from json when null', () {
      final rates = ExchangeRates(
        base: 'USD',
        timestamp: DateTime.now(),
        rates: {},
      );
      expect(rates.toJson().containsKey('source'), isFalse);
    });

    test('throws on missing base', () {
      expect(
        () => ExchangeRates.fromJson({
          'timestamp': '2025-01-01T00:00:00.000Z',
          'rates': {},
        }),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('throws on missing timestamp', () {
      expect(
        () => ExchangeRates.fromJson({
          'base': 'USD',
          'rates': {},
        }),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('throws on missing rates', () {
      expect(
        () => ExchangeRates.fromJson({
          'base': 'USD',
          'timestamp': '2025-01-01T00:00:00.000Z',
        }),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
