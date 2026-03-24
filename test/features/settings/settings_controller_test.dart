import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:hive_test/hive_test.dart';
import 'package:spending_tracker_app/core/currency/currency_service.dart';
import 'package:spending_tracker_app/core/currency/models/exchange_rates.dart';
import 'package:spending_tracker_app/core/currency/primary_currency_converter.dart';
import 'package:spending_tracker_app/features/currency/models/currency.dart';
import 'package:spending_tracker_app/features/currency/data/currency_registry.dart';
import 'package:spending_tracker_app/features/expenses/models/expense.dart';
import 'package:spending_tracker_app/features/settings/settings_controller.dart';

import '../../helpers/fakes.dart';

PrimaryCurrencyConverter _makeConverter(
    FakeExpenseRepository expenseRepo, FakeSettingsRepository settingsRepo, Box settingsBox) {
  final registry = CurrencyRegistry.forTesting({
    'USD': const Currency(
        code: 'USD', name: 'US Dollar', symbol: '\$', decimals: 2, numToBasic: 100),
    'EUR': const Currency(
        code: 'EUR', name: 'Euro', symbol: '\u20AC', decimals: 2, numToBasic: 100),
  });
  final rates = ExchangeRates(
    base: 'USD',
    timestamp: DateTime.now(),
    rates: {'EUR': 0.84},
    source: 'test',
  );
  final currencyService = CurrencyService(rates, registry, settingsBox);
  return PrimaryCurrencyConverter(
    expenseRepository: expenseRepo,
    currencyService: currencyService,
    settingsRepository: settingsRepo,
  );
}

void main() {
  late Box settingsBox;

  setUpAll(() async {
    await setUpTestHive();
    settingsBox = await Hive.openBox('settings');
  });

  tearDownAll(() async => tearDownTestHive());

  group('SettingsController', () {
    test('reads primary currency from repository', () {
      final repo = FakeSettingsRepository(primaryCurrency: 'EUR');
      final controller = SettingsController(repo);
      expect(controller.primaryCurrency, 'EUR');
    });

    test('setPrimaryCurrency updates repository and recents', () {
      final repo = FakeSettingsRepository();
      final controller = SettingsController(repo);

      controller.setPrimaryCurrency('GBP');
      expect(repo.getPrimaryCurrency(), 'GBP');
      expect(controller.recentCurrencies.contains('GBP'), isTrue);
    });

    test('markCurrencyUsed adds to front of recents', () {
      final repo = FakeSettingsRepository();
      final controller = SettingsController(repo);

      controller.markCurrencyUsed('EUR');
      controller.markCurrencyUsed('JPY');

      expect(controller.recentCurrencies.first, 'JPY');
      expect(controller.recentCurrencies.contains('EUR'), isTrue);
    });

    test('recents limited to 5', () {
      final repo = FakeSettingsRepository();
      final controller = SettingsController(repo);

      controller.markCurrencyUsed('EUR');
      controller.markCurrencyUsed('JPY');
      controller.markCurrencyUsed('GBP');
      controller.markCurrencyUsed('AUD');
      controller.markCurrencyUsed('CAD');
      controller.markCurrencyUsed('CHF');

      expect(controller.recentCurrencies.length, 5);
      expect(controller.recentCurrencies.first, 'CHF');
    });

    test('markCurrencyUsed moves existing to front', () {
      final repo = FakeSettingsRepository();
      final controller = SettingsController(repo);

      controller.markCurrencyUsed('EUR');
      controller.markCurrencyUsed('JPY');
      controller.markCurrencyUsed('EUR'); // move to front

      expect(controller.recentCurrencies.first, 'EUR');
    });

    test('recents persisted to repository', () {
      final repo = FakeSettingsRepository();
      final controller = SettingsController(repo);

      controller.markCurrencyUsed('EUR');
      expect(repo.getRecentCurrencies().contains('EUR'), isTrue);
    });

    test('constructor loads recents from repository', () {
      final repo = FakeSettingsRepository(
        recentCurrencies: ['JPY', 'EUR'],
      );
      final controller = SettingsController(repo);

      // USD should be prepended since it's the primary
      expect(controller.recentCurrencies.first, 'USD');
      expect(controller.recentCurrencies.contains('JPY'), isTrue);
      expect(controller.recentCurrencies.contains('EUR'), isTrue);
    });

    test('constructor ensures primary in recents', () {
      final repo = FakeSettingsRepository(
        primaryCurrency: 'GBP',
        recentCurrencies: ['EUR', 'JPY'],
      );
      final controller = SettingsController(repo);
      expect(controller.recentCurrencies.contains('GBP'), isTrue);
    });
  });

  group('firstDayOfWeek', () {
    test('reads and writes', () {
      final repo = FakeSettingsRepository();
      final controller = SettingsController(repo);

      controller.setFirstDayOfWeek(7); // Sunday
      expect(controller.firstDayOfWeek, 7);
    });
  });

  group('onboarding', () {
    test('completeOnboarding sets flag', () {
      final repo = FakeSettingsRepository();
      final controller = SettingsController(repo);

      controller.completeOnboarding();
      expect(controller.isOnboarded, isTrue);
    });
  });

  group('lockedCurrency', () {
    test('set and get', () {
      final repo = FakeSettingsRepository();
      final controller = SettingsController(repo);

      controller.setLockedCurrencyCode('JPY');
      expect(controller.lockedCurrencyCode, 'JPY');

      controller.setLockedCurrencyCode(null);
      expect(controller.lockedCurrencyCode, isNull);
    });
  });

  group('setPrimaryCurrencyWithConversion', () {
    test('converts expenses and updates primary', () {
      final expenseRepo = FakeExpenseRepository();
      final settingsRepo = FakeSettingsRepository(); // primary = USD
      final converter = _makeConverter(expenseRepo, settingsRepo, settingsBox);
      final controller =
          SettingsController(settingsRepo, currencyConverter: converter);

      // Add a USD expense
      expenseRepo.save(Expense(
        id: 'e1',
        amountMinor: 1000,
        date: DateTime.now(),
        currencyCode: 'USD',
      ));

      final count = controller.setPrimaryCurrencyWithConversion('EUR');
      expect(count.converted, 1);
      expect(controller.primaryCurrency, 'EUR');

      // Verify expense was converted
      final converted = expenseRepo.getById('e1')!;
      expect(converted.primaryCurrencyCode, 'EUR');
      expect(converted.amountInPrimary, 840); // 1000 * 0.84
    });

    test('adds new primary to recents', () {
      final expenseRepo = FakeExpenseRepository();
      final settingsRepo = FakeSettingsRepository();
      final converter = _makeConverter(expenseRepo, settingsRepo, settingsBox);
      final controller =
          SettingsController(settingsRepo, currencyConverter: converter);

      controller.setPrimaryCurrencyWithConversion('EUR');
      expect(controller.recentCurrencies.contains('EUR'), isTrue);
    });

    test('returns zero when no expenses to convert', () {
      final expenseRepo = FakeExpenseRepository();
      final settingsRepo = FakeSettingsRepository();
      final converter = _makeConverter(expenseRepo, settingsRepo, settingsBox);
      final controller =
          SettingsController(settingsRepo, currencyConverter: converter);

      final count = controller.setPrimaryCurrencyWithConversion('EUR');
      expect(count.converted, 0);
    });
  });

  group('conversion recovery', () {
    test('runs conversion on startup when flag is set', () {
      final expenseRepo = FakeExpenseRepository();
      final repo = FakeSettingsRepository(conversionInProgress: true);
      final converter = _makeConverter(expenseRepo, repo, settingsBox);

      SettingsController(repo, currencyConverter: converter);
      // Flag should be cleared after successful recovery
      expect(repo.getConversionInProgress(), isFalse);
    });

    test('does not run conversion when flag is not set', () {
      final expenseRepo = FakeExpenseRepository();
      final repo = FakeSettingsRepository(conversionInProgress: false);
      final converter = _makeConverter(expenseRepo, repo, settingsBox);

      SettingsController(repo, currencyConverter: converter);
      expect(repo.getConversionInProgress(), isFalse);
    });
  });
}
