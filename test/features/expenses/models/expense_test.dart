import 'package:flutter_test/flutter_test.dart';
import 'package:spending_tracker_app/features/expenses/models/expense.dart';

Expense _makeExpense({
  String id = 'test-id',
  int amountMinor = 1000,
  String? categoryId,
  String? locationId,
  DateTime? date,
  String currencyCode = 'USD',
  String? note,
  int? amountInPrimary,
  String? primaryCurrencyCode,
  double? rateToPrimary,
  DateTime? conversionDate,
}) {
  return Expense(
    id: id,
    amountMinor: amountMinor,
    categoryId: categoryId,
    locationId: locationId,
    date: date ?? DateTime(2025, 1, 15),
    currencyCode: currencyCode,
    note: note,
    amountInPrimary: amountInPrimary,
    primaryCurrencyCode: primaryCurrencyCode,
    rateToPrimary: rateToPrimary,
    conversionDate: conversionDate,
  );
}

void main() {
  group('validate', () {
    test('valid expense returns no errors', () {
      final expense = _makeExpense();
      expect(expense.validate(), isEmpty);
      expect(expense.isValid, isTrue);
    });

    test('zero amount is invalid', () {
      final expense = _makeExpense(amountMinor: 0);
      final errors = expense.validate();
      expect(errors, contains('Amount must be greater than zero'));
    });

    test('negative amount is invalid', () {
      final expense = _makeExpense(amountMinor: -100);
      expect(expense.validate(), isNotEmpty);
    });

    test('amount exceeding max is invalid', () {
      final expense = _makeExpense(amountMinor: Expense.maxAmountMinor + 1);
      final errors = expense.validate();
      expect(errors, contains('Amount exceeds maximum allowed value'));
    });

    test('amount at max is valid', () {
      final expense = _makeExpense(amountMinor: Expense.maxAmountMinor);
      expect(expense.validate(), isEmpty);
    });

    test('empty currency code is invalid', () {
      final expense = _makeExpense(currencyCode: '');
      expect(expense.validate(), isNotEmpty);
    });

    test('2-letter currency code is invalid', () {
      final expense = _makeExpense(currencyCode: 'US');
      expect(expense.validate(), isNotEmpty);
    });

    test('4-letter currency code is invalid', () {
      final expense = _makeExpense(currencyCode: 'USDD');
      expect(expense.validate(), isNotEmpty);
    });

    test('note exceeding max length is invalid', () {
      final longNote = 'x' * (Expense.maxNoteLength + 1);
      final expense = _makeExpense(note: longNote);
      expect(expense.validate(), isNotEmpty);
    });

    test('note at max length is valid', () {
      final maxNote = 'x' * Expense.maxNoteLength;
      final expense = _makeExpense(note: maxNote);
      expect(expense.validate(), isEmpty);
    });

    test('null note is valid', () {
      final expense = _makeExpense(note: null);
      expect(expense.validate(), isEmpty);
    });

    test('multiple errors returned together', () {
      final expense = _makeExpense(amountMinor: 0, currencyCode: '');
      expect(expense.validate().length, greaterThanOrEqualTo(2));
    });
  });

  group('copyWith', () {
    test('copies all fields when no overrides', () {
      final original = _makeExpense(
        categoryId: 'cat-1',
        locationId: 'loc-1',
        note: 'lunch',
      );
      final copy = original.copyWith();
      expect(copy.id, original.id);
      expect(copy.amountMinor, original.amountMinor);
      expect(copy.categoryId, original.categoryId);
      expect(copy.locationId, original.locationId);
      expect(copy.note, original.note);
      expect(copy.currencyCode, original.currencyCode);
    });

    test('overrides specific fields', () {
      final original = _makeExpense();
      final copy = original.copyWith(amountMinor: 2000, currencyCode: 'EUR');
      expect(copy.amountMinor, 2000);
      expect(copy.currencyCode, 'EUR');
      expect(copy.id, original.id); // unchanged
    });

    test('clearCategoryId sets categoryId to null', () {
      final original = _makeExpense(categoryId: 'cat-1');
      final copy = original.copyWith(clearCategoryId: true);
      expect(copy.categoryId, isNull);
    });

    test('clearLocationId sets locationId to null', () {
      final original = _makeExpense(locationId: 'loc-1');
      final copy = original.copyWith(clearLocationId: true);
      expect(copy.locationId, isNull);
    });

    test('clearNote sets note to null', () {
      final original = _makeExpense(note: 'test');
      final copy = original.copyWith(clearNote: true);
      expect(copy.note, isNull);
    });

    test('clear flags take precedence over new values', () {
      final original = _makeExpense(categoryId: 'cat-1');
      final copy = original.copyWith(categoryId: 'cat-2', clearCategoryId: true);
      expect(copy.categoryId, isNull);
    });

    test('preserves createdAt, updates updatedAt', () {
      final original = _makeExpense();
      final copy = original.copyWith(amountMinor: 2000);
      expect(copy.createdAt, original.createdAt);
      // updatedAt should be updated (at least not before original)
      expect(copy.updatedAt.millisecondsSinceEpoch,
          greaterThanOrEqualTo(original.updatedAt.millisecondsSinceEpoch));
    });
  });

  group('hasPrimaryConversion', () {
    test('returns true when both fields set', () {
      final expense = _makeExpense(
          amountInPrimary: 840, primaryCurrencyCode: 'EUR');
      expect(expense.hasPrimaryConversion, isTrue);
    });

    test('returns false when amountInPrimary is null', () {
      final expense = _makeExpense(primaryCurrencyCode: 'EUR');
      expect(expense.hasPrimaryConversion, isFalse);
    });

    test('returns false when primaryCurrencyCode is null', () {
      final expense = _makeExpense(amountInPrimary: 840);
      // primaryCurrencyCode defaults to null in the constructor
      // but fromMap defaults it to 'USD'. Direct construction → null
      expect(expense.hasPrimaryConversion, isFalse);
    });
  });

  group('toMap / fromMap round-trip', () {
    test('minimal expense round-trips correctly', () {
      final original = _makeExpense();
      final map = original.toMap();
      final restored = Expense.fromMap(map);

      expect(restored.id, original.id);
      expect(restored.amountMinor, original.amountMinor);
      expect(restored.currencyCode, original.currencyCode);
      expect(restored.date.year, original.date.year);
      expect(restored.date.month, original.date.month);
      expect(restored.date.day, original.date.day);
    });

    test('full expense round-trips correctly', () {
      final original = _makeExpense(
        categoryId: 'cat-1',
        locationId: 'loc-1',
        note: 'dinner',
        amountInPrimary: 840,
        primaryCurrencyCode: 'EUR',
        rateToPrimary: 0.84,
        conversionDate: DateTime(2025, 1, 15, 12, 0),
      );
      final map = original.toMap();
      final restored = Expense.fromMap(map);

      expect(restored.categoryId, 'cat-1');
      expect(restored.locationId, 'loc-1');
      expect(restored.note, 'dinner');
      expect(restored.amountInPrimary, 840);
      expect(restored.primaryCurrencyCode, 'EUR');
      expect(restored.rateToPrimary, 0.84);
    });

    test('optional fields are excluded from map when null', () {
      final expense = _makeExpense();
      final map = expense.toMap();
      expect(map.containsKey('categoryId'), isFalse);
      expect(map.containsKey('locationId'), isFalse);
      expect(map.containsKey('note'), isFalse);
    });
  });

  group('fromMap — required field validation', () {
    test('throws on missing id', () {
      expect(
        () => Expense.fromMap({'amountMinor': 100, 'date': '2025-01-15', 'currencyCode': 'USD'}),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('throws on missing amountMinor', () {
      expect(
        () => Expense.fromMap({'id': 'x', 'date': '2025-01-15', 'currencyCode': 'USD'}),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('throws on missing date', () {
      expect(
        () => Expense.fromMap({'id': 'x', 'amountMinor': 100, 'currencyCode': 'USD'}),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('throws on missing currencyCode', () {
      expect(
        () => Expense.fromMap({'id': 'x', 'amountMinor': 100, 'date': '2025-01-15'}),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('fromMap — legacy migration', () {
    test('empty categoryId mapped to null', () {
      final expense = Expense.fromMap({
        'id': 'x',
        'amountMinor': 100,
        'date': '2025-01-15',
        'currencyCode': 'USD',
        'categoryId': '',
      });
      expect(expense.categoryId, isNull);
    });

    test('empty locationId mapped to null', () {
      final expense = Expense.fromMap({
        'id': 'x',
        'amountMinor': 100,
        'date': '2025-01-15',
        'currencyCode': 'USD',
        'locationId': '',
      });
      expect(expense.locationId, isNull);
    });

    test('legacy amountInUsd migrates to amountInPrimary', () {
      final expense = Expense.fromMap({
        'id': 'x',
        'amountMinor': 100,
        'date': '2025-01-15',
        'currencyCode': 'EUR',
        'amountInUsd': 119,
      });
      expect(expense.amountInPrimary, 119);
      expect(expense.primaryCurrencyCode, 'USD');
    });

    test('legacy rateToUsd migrates to rateToPrimary', () {
      final expense = Expense.fromMap({
        'id': 'x',
        'amountMinor': 100,
        'date': '2025-01-15',
        'currencyCode': 'EUR',
        'rateToUsd': 1.19,
      });
      expect(expense.rateToPrimary, 1.19);
    });

    test('amountInPrimary takes precedence over amountInUsd', () {
      final expense = Expense.fromMap({
        'id': 'x',
        'amountMinor': 100,
        'date': '2025-01-15',
        'currencyCode': 'EUR',
        'amountInPrimary': 84,
        'amountInUsd': 119,
        'primaryCurrencyCode': 'EUR',
      });
      expect(expense.amountInPrimary, 84);
      expect(expense.primaryCurrencyCode, 'EUR');
    });
  });
}
