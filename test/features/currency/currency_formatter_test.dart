import 'package:flutter_test/flutter_test.dart';
import 'package:spending_tracker_app/features/currency/formatters/currency_formatter.dart';
import 'package:spending_tracker_app/features/currency/models/currency.dart';

const _usd = Currency(
    code: 'USD', name: 'US Dollar', symbol: '\$', decimals: 2, numToBasic: 100);
const _eur = Currency(
    code: 'EUR', name: 'Euro', symbol: '\u20AC', decimals: 2, numToBasic: 100);
const _jpy = Currency(
    code: 'JPY', name: 'Japanese Yen', symbol: '\u00A5', decimals: 0, numToBasic: 1);
const _bhd = Currency(
    code: 'BHD', name: 'Bahraini Dinar', symbol: 'BD', decimals: 3, numToBasic: 1000);
const _krw = Currency(
    code: 'KRW', name: 'South Korean Won', symbol: '\u20A9', decimals: 0, numToBasic: 1);

void main() {
  group('CurrencyFormatter.formatMinor', () {
    // ── 2-decimal currencies (USD, EUR) ──────────────────────────────────

    test('formats USD whole dollars', () {
      expect(CurrencyFormatter.formatMinor(1000, _usd), '\$ 10.00');
    });

    test('formats USD with cents', () {
      expect(CurrencyFormatter.formatMinor(1050, _usd), '\$ 10.50');
    });

    test('formats USD one cent', () {
      expect(CurrencyFormatter.formatMinor(1, _usd), '\$ 0.01');
    });

    test('formats USD zero', () {
      expect(CurrencyFormatter.formatMinor(0, _usd), '\$ 0.00');
    });

    test('formats EUR', () {
      expect(CurrencyFormatter.formatMinor(840, _eur), '\u20AC 8.40');
    });

    test('formats large USD amount', () {
      // $99,999.99 = 9999999 minor
      expect(CurrencyFormatter.formatMinor(9999999, _usd), '\$ 99999.99');
    });

    // ── 0-decimal currencies (JPY, KRW) ──────────────────────────────────

    test('formats JPY no decimals', () {
      expect(CurrencyFormatter.formatMinor(1530, _jpy), '\u00A5 1530');
    });

    test('formats JPY zero', () {
      expect(CurrencyFormatter.formatMinor(0, _jpy), '\u00A5 0');
    });

    test('formats JPY single yen', () {
      expect(CurrencyFormatter.formatMinor(1, _jpy), '\u00A5 1');
    });

    test('formats KRW no decimals', () {
      expect(CurrencyFormatter.formatMinor(50000, _krw), '\u20A9 50000');
    });

    // ── 3-decimal currencies (BHD) ───────────────────────────────────────

    test('formats BHD three decimals', () {
      expect(CurrencyFormatter.formatMinor(1500, _bhd), 'BD 1.500');
    });

    test('formats BHD fractional', () {
      expect(CurrencyFormatter.formatMinor(1, _bhd), 'BD 0.001');
    });

    test('formats BHD whole dinar', () {
      expect(CurrencyFormatter.formatMinor(1000, _bhd), 'BD 1.000');
    });
  });
}
