import 'package:flutter_test/flutter_test.dart';
import 'package:spending_tracker_app/features/currency/currency_amount.dart';
import 'package:spending_tracker_app/features/currency/models/currency.dart';

const _usd = Currency(
    code: 'USD', name: 'US Dollar', symbol: '\$', decimals: 2, numToBasic: 100);
const _jpy = Currency(
    code: 'JPY', name: 'Japanese Yen', symbol: '\u00A5', decimals: 0, numToBasic: 1);
const _bhd = Currency(
    code: 'BHD', name: 'Bahraini Dinar', symbol: 'BD', decimals: 3, numToBasic: 1000);

void main() {
  group('parseCurrencyAmount', () {
    // ── USD (2-decimal, numToBasic=100) ──────────────────────────────────

    test('parses whole dollars', () {
      final result = parseCurrencyAmount('10', _usd);
      expect(result.isValid, isTrue);
      expect(result.minorUnits, 1000);
    });

    test('parses dollars with cents', () {
      final result = parseCurrencyAmount('10.50', _usd);
      expect(result.isValid, isTrue);
      expect(result.minorUnits, 1050);
    });

    test('parses comma as decimal separator', () {
      final result = parseCurrencyAmount('10,50', _usd);
      expect(result.isValid, isTrue);
      expect(result.minorUnits, 1050);
    });

    test('parses zero', () {
      final result = parseCurrencyAmount('0', _usd);
      expect(result.isValid, isTrue);
      expect(result.minorUnits, 0);
    });

    test('parses fractional cents (rounds)', () {
      // 10.555 * 100 = 1055.5 → rounds to 1056
      final result = parseCurrencyAmount('10.555', _usd);
      expect(result.isValid, isTrue);
      expect(result.minorUnits, 1056);
    });

    // ── JPY (0-decimal, numToBasic=1) ────────────────────────────────────

    test('parses JPY whole yen', () {
      final result = parseCurrencyAmount('1530', _jpy);
      expect(result.isValid, isTrue);
      expect(result.minorUnits, 1530);
    });

    test('parses JPY with decimal (rounds)', () {
      // Users might type "1530.5" — rounds to 1531
      final result = parseCurrencyAmount('1530.5', _jpy);
      expect(result.isValid, isTrue);
      expect(result.minorUnits, 1531);
    });

    // ── BHD (3-decimal, numToBasic=1000) ─────────────────────────────────

    test('parses BHD three decimals', () {
      final result = parseCurrencyAmount('1.500', _bhd);
      expect(result.isValid, isTrue);
      expect(result.minorUnits, 1500);
    });

    test('parses BHD whole dinar', () {
      final result = parseCurrencyAmount('5', _bhd);
      expect(result.isValid, isTrue);
      expect(result.minorUnits, 5000);
    });

    // ── Validation / error cases ─────────────────────────────────────────

    test('rejects empty string', () {
      final result = parseCurrencyAmount('', _usd);
      expect(result.isValid, isFalse);
      expect(result.error, isNotNull);
    });

    test('rejects non-numeric input', () {
      final result = parseCurrencyAmount('abc', _usd);
      expect(result.isValid, isFalse);
    });

    test('rejects negative amount', () {
      final result = parseCurrencyAmount('-5', _usd);
      expect(result.isValid, isFalse);
    });

    test('rejects NaN', () {
      final result = parseCurrencyAmount('NaN', _usd);
      expect(result.isValid, isFalse);
    });
  });
}
