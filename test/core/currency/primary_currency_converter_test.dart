import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:hive_test/hive_test.dart';
import 'package:spending_tracker_app/core/currency/currency_service.dart';
import 'package:spending_tracker_app/core/currency/models/exchange_rates.dart';
import 'package:spending_tracker_app/core/currency/primary_currency_converter.dart';
import 'package:spending_tracker_app/features/currency/models/currency.dart';
import 'package:spending_tracker_app/features/currency/data/currency_registry.dart';
import 'package:spending_tracker_app/features/expenses/models/expense.dart';

import '../../helpers/fakes.dart';

CurrencyRegistry _testRegistry() => CurrencyRegistry.forTesting({
      'USD': const Currency(
          code: 'USD', name: 'US Dollar', symbol: '\$', decimals: 2, numToBasic: 100),
      'EUR': const Currency(
          code: 'EUR', name: 'Euro', symbol: '\u20AC', decimals: 2, numToBasic: 100),
      'JPY': const Currency(
          code: 'JPY', name: 'Japanese Yen', symbol: '\u00A5', decimals: 0, numToBasic: 1),
    });

ExchangeRates _freshRates() => ExchangeRates(
      base: 'USD',
      timestamp: DateTime.now(),
      rates: {'EUR': 0.84, 'JPY': 153.0},
      source: 'test',
    );

Expense _makeExpense({
  String id = 'exp-1',
  int amountMinor = 1000,
  String currencyCode = 'USD',
  int? amountInPrimary,
  String? primaryCurrencyCode,
}) {
  return Expense(
    id: id,
    amountMinor: amountMinor,
    date: DateTime(2025, 1, 15),
    currencyCode: currencyCode,
    amountInPrimary: amountInPrimary,
    primaryCurrencyCode: primaryCurrencyCode,
  );
}

void main() {
  late FakeExpenseRepository expenseRepo;
  late FakeSettingsRepository settingsRepo;
  late CurrencyService currencyService;
  late PrimaryCurrencyConverter converter;

  late Box settingsBox;

  setUp(() async {
    await setUpTestHive();
    settingsBox = await Hive.openBox('settings');
    expenseRepo = FakeExpenseRepository();
    settingsRepo = FakeSettingsRepository();
    currencyService = CurrencyService(_freshRates(), _testRegistry(), settingsBox);
    converter = PrimaryCurrencyConverter(
      expenseRepository: expenseRepo,
      currencyService: currencyService,
      settingsRepository: settingsRepo,
    );
  });

  tearDown(() async => tearDownTestHive());

  group('convertAllExpensesToPrimaryCurrency', () {
    test('converts USD expenses to EUR', () {
      expenseRepo.save(_makeExpense(id: 'e1', amountMinor: 1000, currencyCode: 'USD'));

      final count = converter.convertAllExpensesToPrimaryCurrency('EUR');
      expect(count.converted, 1);

      final converted = expenseRepo.getById('e1')!;
      expect(converted.primaryCurrencyCode, 'EUR');
      // 1000 USD cents * 1.0 * 0.84 * (100/100) = 840 EUR cents
      expect(converted.amountInPrimary, 840);
    });

    test('converts EUR expenses to USD', () {
      expenseRepo.save(_makeExpense(id: 'e1', amountMinor: 840, currencyCode: 'EUR'));

      final count = converter.convertAllExpensesToPrimaryCurrency('USD');
      expect(count.converted, 1);

      final converted = expenseRepo.getById('e1')!;
      expect(converted.primaryCurrencyCode, 'USD');
      // 840 * (1/0.84) * 1.0 * (100/100) = 1000
      expect(converted.amountInPrimary, 1000);
    });

    test('converts JPY expenses to EUR (cross-numToBasic)', () {
      expenseRepo.save(_makeExpense(id: 'e1', amountMinor: 500, currencyCode: 'JPY'));

      final count = converter.convertAllExpensesToPrimaryCurrency('EUR');
      expect(count.converted, 1);

      final converted = expenseRepo.getById('e1')!;
      // 500 * (1/153) * 0.84 * (100/1) ≈ 275
      expect(converted.amountInPrimary, closeTo(275, 2));
    });

    test('converts multiple expenses', () {
      expenseRepo.save(_makeExpense(id: 'e1', amountMinor: 1000, currencyCode: 'USD'));
      expenseRepo.save(_makeExpense(id: 'e2', amountMinor: 500, currencyCode: 'JPY'));
      expenseRepo.save(_makeExpense(id: 'e3', amountMinor: 840, currencyCode: 'EUR'));

      final count = converter.convertAllExpensesToPrimaryCurrency('EUR');
      expect(count.converted, 3);
    });

    test('sets and clears conversion safety flag', () {
      expenseRepo.save(_makeExpense());

      // Should be false before and after
      expect(settingsRepo.getConversionInProgress(), isFalse);
      converter.convertAllExpensesToPrimaryCurrency('EUR');
      expect(settingsRepo.getConversionInProgress(), isFalse);
    });

    test('throws for unsupported currency', () {
      expect(
        () => converter.convertAllExpensesToPrimaryCurrency('XYZ'),
        throwsA(isA<UnsupportedError>()),
      );
    });

    test('calls onExpensesModified callback', () {
      int callCount = 0;
      converter.onExpensesModified = () => callCount++;
      expenseRepo.save(_makeExpense());

      converter.convertAllExpensesToPrimaryCurrency('EUR');
      expect(callCount, 1);
    });

    test('handles empty repository', () {
      final count = converter.convertAllExpensesToPrimaryCurrency('EUR');
      expect(count.converted, 0);
    });

    test('stores rateToPrimary for display', () {
      expenseRepo.save(_makeExpense(id: 'e1', amountMinor: 1000, currencyCode: 'USD'));

      converter.convertAllExpensesToPrimaryCurrency('EUR');
      final converted = expenseRepo.getById('e1')!;

      // rateToPrimary = rateToUsd * rateFromUsd = 1.0 * 0.84 = 0.84
      expect(converted.rateToPrimary, closeTo(0.84, 0.01));
    });

    test('stores conversionDate', () {
      expenseRepo.save(_makeExpense(id: 'e1'));
      final before = DateTime.now();

      converter.convertAllExpensesToPrimaryCurrency('EUR');
      final converted = expenseRepo.getById('e1')!;

      expect(converted.conversionDate, isNotNull);
      expect(converted.conversionDate!.isAfter(before.subtract(const Duration(seconds: 1))), isTrue);
    });
  });
}
