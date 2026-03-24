import 'package:flutter_test/flutter_test.dart';
import 'package:spending_tracker_app/features/expenses/models/expense_totals.dart';

void main() {
  group('SpendingComparison', () {
    test('can be constructed with null fields (no baseline)', () {
      const comparison = SpendingComparison();
      expect(comparison.text, isNull);
      expect(comparison.isPositive, isNull);
    });

    test('holds decrease data', () {
      const comparison = SpendingComparison(text: '↓12% vs last week', isPositive: true);
      expect(comparison.text, '↓12% vs last week');
      expect(comparison.isPositive, isTrue);
    });

    test('holds increase data', () {
      const comparison = SpendingComparison(text: '↑8% vs last week', isPositive: false);
      expect(comparison.isPositive, isFalse);
    });
  });

  group('CurrencyAmount', () {
    test('holds code and amount', () {
      const amount = CurrencyAmount(currencyCode: 'USD', amountMinor: 1500);
      expect(amount.currencyCode, 'USD');
      expect(amount.amountMinor, 1500);
    });

    test('zero amount is valid', () {
      const amount = CurrencyAmount(currencyCode: 'JPY', amountMinor: 0);
      expect(amount.amountMinor, 0);
    });
  });

  group('CurrencyBreakdownHelper.fromMap', () {
    test('returns empty list for empty map', () {
      expect(CurrencyBreakdownHelper.fromMap({}), isEmpty);
    });

    test('single currency returns single item', () {
      final result = CurrencyBreakdownHelper.fromMap({'USD': 1000});
      expect(result.length, 1);
      expect(result.first.currencyCode, 'USD');
      expect(result.first.amountMinor, 1000);
    });

    test('sorts by amount descending', () {
      final result = CurrencyBreakdownHelper.fromMap({
        'EUR': 500,
        'USD': 2000,
        'JPY': 1200,
      });
      expect(result[0].currencyCode, 'USD'); // 2000
      expect(result[1].currencyCode, 'JPY'); // 1200
      expect(result[2].currencyCode, 'EUR'); // 500
    });

    test('equal amounts preserve order (stable sort not required, just no crash)', () {
      final result = CurrencyBreakdownHelper.fromMap({'USD': 500, 'EUR': 500});
      expect(result.length, 2);
      expect(result.every((a) => a.amountMinor == 500), isTrue);
    });
  });

  group('DailyTotal', () {
    test('holds date and total', () {
      final total = DailyTotal(date: DateTime(2025, 6, 15), totalMinor: 2500);
      expect(total.totalMinor, 2500);
      expect(total.date, DateTime(2025, 6, 15));
    });

    test('defaults to empty currency breakdown', () {
      final total = DailyTotal(date: DateTime(2025, 1, 1), totalMinor: 0);
      expect(total.currencyBreakdown, isEmpty);
    });

    test('accepts currency breakdown', () {
      final total = DailyTotal(
        date: DateTime(2025, 1, 1),
        totalMinor: 1000,
        currencyBreakdown: const [CurrencyAmount(currencyCode: 'USD', amountMinor: 1000)],
      );
      expect(total.currencyBreakdown.length, 1);
    });
  });

  group('CategoryTotal', () {
    test('holds all fields', () {
      const total = CategoryTotal(
        categoryId: 'cat-1',
        categoryName: 'Food',
        totalMinor: 3000,
        count: 5,
      );
      expect(total.categoryId, 'cat-1');
      expect(total.categoryName, 'Food');
      expect(total.totalMinor, 3000);
      expect(total.count, 5);
    });

    test('defaults to empty currency breakdown', () {
      const total = CategoryTotal(
        categoryId: 'cat-1',
        categoryName: 'Food',
        totalMinor: 0,
        count: 0,
      );
      expect(total.currencyBreakdown, isEmpty);
    });
  });

  group('LocationTotal', () {
    test('holds all fields', () {
      const total = LocationTotal(
        locationId: 'loc-1',
        locationName: 'Coffee Shop',
        totalMinor: 800,
        count: 3,
      );
      expect(total.locationId, 'loc-1');
      expect(total.locationName, 'Coffee Shop');
      expect(total.totalMinor, 800);
      expect(total.count, 3);
    });

    test('defaults to empty currency breakdown', () {
      const total = LocationTotal(
        locationId: 'loc-1',
        locationName: 'Coffee Shop',
        totalMinor: 0,
        count: 0,
      );
      expect(total.currencyBreakdown, isEmpty);
    });
  });
}
