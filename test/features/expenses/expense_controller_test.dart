import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:hive_test/hive_test.dart';
import 'package:spending_tracker_app/core/currency/currency_service.dart';
import 'package:spending_tracker_app/core/currency/models/exchange_rates.dart';
import 'package:spending_tracker_app/features/currency/models/currency.dart';
import 'package:spending_tracker_app/features/currency/data/currency_registry.dart';
import 'package:spending_tracker_app/features/expenses/expense_controller.dart';
import 'package:spending_tracker_app/features/expenses/models/expense.dart';
import 'package:spending_tracker_app/features/settings/settings_controller.dart';

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
  DateTime? date,
  String? categoryId,
  String? locationId,
  String? note,
  int? amountInPrimary,
  String? primaryCurrencyCode,
}) {
  return Expense(
    id: id,
    amountMinor: amountMinor,
    date: date ?? DateTime.now(),
    currencyCode: currencyCode,
    categoryId: categoryId,
    locationId: locationId,
    note: note,
    amountInPrimary: amountInPrimary ?? amountMinor,
    primaryCurrencyCode: primaryCurrencyCode ?? 'USD',
  );
}

void main() {
  late FakeExpenseRepository expenseRepo;
  late FakeCategoryRepository categoryRepo;
  late FakeLocationRepository locationRepo;
  late CurrencyService currencyService;
  late SettingsController settingsController;
  late ExpenseController controller;

  late Box settingsBox;

  setUp(() async {
    await setUpTestHive();
    settingsBox = await Hive.openBox('settings');
    expenseRepo = FakeExpenseRepository();
    categoryRepo = FakeCategoryRepository();
    locationRepo = FakeLocationRepository();
    currencyService = CurrencyService(_freshRates(), _testRegistry(), settingsBox);
    final settingsRepo = FakeSettingsRepository();
    settingsController = SettingsController(settingsRepo);
    controller = ExpenseController(
      expenseRepo,
      categoryRepo,
      locationRepo,
      currencyService,
      settingsController,
    );
  });

  tearDown(() async => tearDownTestHive());

  group('CRUD operations', () {
    test('add inserts expense and notifies', () {
      int notifyCount = 0;
      controller.addListener(() => notifyCount++);

      controller.add(_makeExpense(id: 'e1', amountMinor: 500));

      expect(controller.all.length, 1);
      expect(controller.all.first.id, 'e1');
      expect(notifyCount, greaterThan(0));
    });

    test('add rejects invalid expense', () {
      // assert fires in debug mode before the early return
      expect(
        () => controller.add(_makeExpense(id: 'e1', amountMinor: 0)),
        throwsA(isA<AssertionError>()),
      );
      expect(controller.all, isEmpty);
    });

    test('update modifies existing expense', () {
      final original = _makeExpense(id: 'e1', amountMinor: 500);
      controller.add(original);

      final updated = original.copyWith(amountMinor: 750);
      controller.update(updated);

      expect(controller.all.first.amountMinor, 750);
    });

    test('update rejects invalid expense', () {
      final original = _makeExpense(id: 'e1', amountMinor: 500);
      controller.add(original);

      final invalid = original.copyWith(amountMinor: 0);
      // assert fires in debug mode before the early return
      expect(
        () => controller.update(invalid),
        throwsA(isA<AssertionError>()),
      );

      // Should remain unchanged
      expect(controller.all.first.amountMinor, 500);
    });

    test('update ignores non-existent id', () {
      controller.update(_makeExpense(id: 'nonexistent'));
      expect(controller.all, isEmpty);
    });

    test('delete removes expense and returns it', () {
      controller.add(_makeExpense(id: 'e1'));
      final removed = controller.delete('e1');

      expect(removed, isNotNull);
      expect(removed!.id, 'e1');
      expect(controller.all, isEmpty);
    });

    test('delete returns null for non-existent id', () {
      expect(controller.delete('nonexistent'), isNull);
    });

    test('clearAll removes all expenses', () {
      controller.add(_makeExpense(id: 'e1'));
      controller.add(_makeExpense(id: 'e2'));
      controller.clearAll();
      expect(controller.all, isEmpty);
    });
  });

  group('sorting', () {
    test('expenses sorted by date descending', () {
      controller.add(_makeExpense(id: 'e1', date: DateTime(2025, 1, 10)));
      controller.add(_makeExpense(id: 'e2', date: DateTime(2025, 1, 15)));
      controller.add(_makeExpense(id: 'e3', date: DateTime(2025, 1, 5)));

      final ids = controller.all.map((e) => e.id).toList();
      expect(ids, ['e2', 'e1', 'e3']);
    });
  });

  group('pagination', () {
    test('visibleExpenses respects page size', () {
      for (int i = 0; i < 40; i++) {
        controller.add(_makeExpense(
          id: 'e$i',
          date: DateTime(2025, 1, 1).add(Duration(days: i)),
        ));
      }

      expect(controller.visibleExpenses.length, ExpenseController.pageSize);
      expect(controller.canLoadMore, isTrue);
    });

    test('loadMore increases visible count', () {
      for (int i = 0; i < 40; i++) {
        controller.add(_makeExpense(
          id: 'e$i',
          date: DateTime(2025, 1, 1).add(Duration(days: i)),
        ));
      }

      controller.loadMore();
      expect(controller.visibleExpenses.length, 40);
      expect(controller.canLoadMore, isFalse);
    });
  });

  group('totals', () {
    test('totalToday counts only today expenses', () {
      final today = DateTime.now();
      final yesterday = today.subtract(const Duration(days: 1));

      controller.add(_makeExpense(id: 'e1', amountMinor: 500, date: today));
      controller.add(_makeExpense(id: 'e2', amountMinor: 300, date: yesterday));

      expect(controller.totalToday, 500);
    });

    test('totalAllTime sums all expenses', () {
      controller.add(_makeExpense(id: 'e1', amountMinor: 500));
      controller.add(_makeExpense(id: 'e2', amountMinor: 300));
      controller.add(_makeExpense(id: 'e3', amountMinor: 200));

      expect(controller.totalAllTime, 1000);
    });

    test('totalThisWeek includes expenses from start of current calendar week', () {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      // FakeSettingsRepository defaults to Monday start (DateTime.monday == 1)
      final daysFromWeekStart = (today.weekday - DateTime.monday + 7) % 7;
      final weekStart = today.subtract(Duration(days: daysFromWeekStart));
      final beforeWeek = weekStart.subtract(const Duration(days: 1));

      controller.add(_makeExpense(id: 'e1', amountMinor: 500, date: weekStart));
      controller.add(_makeExpense(id: 'e2', amountMinor: 300, date: beforeWeek));

      expect(controller.totalThisWeek, 500); // weekStart included, day before excluded
    });

    test('totalThisMonth includes current month only', () {
      final now = DateTime.now();
      final thisMonth = DateTime(now.year, now.month, 5);
      final lastMonth = DateTime(
        now.month == 1 ? now.year - 1 : now.year,
        now.month == 1 ? 12 : now.month - 1,
        5,
      );

      controller.add(_makeExpense(id: 'e1', amountMinor: 500, date: thisMonth));
      controller.add(_makeExpense(id: 'e2', amountMinor: 300, date: lastMonth));

      expect(controller.totalThisMonth, 500);
    });

    test('totals use primary conversion when available', () {
      final expense = _makeExpense(
        id: 'e1',
        amountMinor: 1000,
        currencyCode: 'EUR',
        amountInPrimary: 1190,
        primaryCurrencyCode: 'USD',
      );
      controller.add(expense);

      // Should use amountInPrimary (1190) since primaryCurrencyCode matches settings
      expect(controller.totalAllTime, 1190);
    });
  });

  group('averages', () {
    test('dailyAverage uses calendar days since first expense', () {
      final today = DateTime.now();
      // Add expense 10 days ago and today
      controller.add(_makeExpense(
          id: 'e1', amountMinor: 1000, date: today.subtract(const Duration(days: 9))));
      controller.add(_makeExpense(id: 'e2', amountMinor: 1000, date: today));

      // Total = 2000, days = 10 (day 0 through day 9 inclusive)
      // Average = 2000 / 10 = 200
      expect(controller.dailyAverage, 200);
    });

    test('weeklyAverage uses calendar weeks', () {
      final today = DateTime.now();
      // 14 days = 2 full weeks
      controller.add(_makeExpense(
          id: 'e1', amountMinor: 700, date: today.subtract(const Duration(days: 13))));
      controller.add(_makeExpense(id: 'e2', amountMinor: 700, date: today));

      // Total = 1400, dayCount = 14, weekCount = (14+6)/7 = 2
      // Weekly average = 1400 / 2 = 700 (but dayCount is 14, weekCount = ceil(14/7)=2)
      // Actually: dayCount = 14, weekCount = max(1, (14+6)~/7) = 20~/7 = 2
      expect(controller.weeklyAverage, 700);
    });

    test('averages handle single expense', () {
      controller.add(_makeExpense(id: 'e1', amountMinor: 1000));

      // Single expense today: dayCount = 1, weekCount = 1
      expect(controller.dailyAverage, 1000);
      expect(controller.weeklyAverage, 1000);
    });

    test('averages handle empty data', () {
      expect(controller.dailyAverage, 0);
      expect(controller.weeklyAverage, 0);
      expect(controller.monthlyAverage, 0);
    });
  });

  group('category grouping', () {
    test('groups expenses by categoryId', () {
      controller.add(_makeExpense(id: 'e1', categoryId: 'cat-1'));
      controller.add(_makeExpense(id: 'e2', categoryId: 'cat-1'));
      controller.add(_makeExpense(id: 'e3', categoryId: 'cat-2'));
      controller.add(_makeExpense(id: 'e4')); // uncategorized

      final groups = controller.expensesByCategory;
      expect(groups['cat-1']?.length, 2);
      expect(groups['cat-2']?.length, 1);
      expect(groups['']?.length, 1); // uncategorized uses empty string
    });

    test('orderedCategoryIds sorted by count descending', () {
      controller.add(_makeExpense(id: 'e1', categoryId: 'cat-a'));
      controller.add(_makeExpense(id: 'e2', categoryId: 'cat-b'));
      controller.add(_makeExpense(id: 'e3', categoryId: 'cat-b'));

      final ordered = controller.orderedCategoryIds;
      expect(ordered.first, 'cat-b');
    });

    test('isCategoryUsed', () {
      controller.add(_makeExpense(id: 'e1', categoryId: 'cat-1'));

      expect(controller.isCategoryUsed('cat-1'), isTrue);
      expect(controller.isCategoryUsed('cat-2'), isFalse);
    });
  });

  group('location grouping', () {
    test('groups expenses by locationId', () {
      controller.add(_makeExpense(id: 'e1', locationId: 'loc-1'));
      controller.add(_makeExpense(id: 'e2', locationId: 'loc-1'));
      controller.add(_makeExpense(id: 'e3')); // no location

      final groups = controller.expensesByLocation;
      expect(groups['loc-1']?.length, 2);
      expect(groups['']?.length, 1); // no location uses empty string
    });
  });

  group('reload and invalidate', () {
    test('reload re-reads from repository', () {
      // Add directly to repo, bypassing controller
      expenseRepo.save(_makeExpense(id: 'external'));

      expect(controller.all.length, 0); // Not loaded yet
      controller.reload();
      expect(controller.all.length, 1);
    });

    test('invalidateTotals marks totals as stale', () {
      controller.add(_makeExpense(id: 'e1', amountMinor: 500));
      // Access totals to force computation
      expect(controller.totalAllTime, 500);

      // Invalidate and check recomputation still works
      controller.invalidateTotals();
      expect(controller.totalAllTime, 500);
    });
  });

  group('firstExpenseDate', () {
    test('returns null when no expenses', () {
      expect(controller.firstExpenseDate, isNull);
    });

    test('returns earliest date', () {
      controller.add(_makeExpense(id: 'e1', date: DateTime(2025, 3, 10)));
      controller.add(_makeExpense(id: 'e2', date: DateTime(2025, 1, 5)));
      controller.add(_makeExpense(id: 'e3', date: DateTime(2025, 2, 20)));

      final first = controller.firstExpenseDate!;
      expect(first.year, 2025);
      expect(first.month, 1);
      expect(first.day, 5);
    });
  });

  // ───────────────────────────────────────────────────────────────────────
  // _convertToPrimary fallback paths
  // ───────────────────────────────────────────────────────────────────────

  group('_convertToPrimary fallback paths', () {
    test('uses stored amountInPrimary when primaryCurrencyCode matches', () {
      // Primary is USD, expense has amountInPrimary stored with USD
      controller.add(_makeExpense(
        id: 'e1',
        amountMinor: 840,
        currencyCode: 'EUR',
        amountInPrimary: 1000,
        primaryCurrencyCode: 'USD',
      ));
      expect(controller.totalAllTime, 1000); // uses stored value, not live conversion
    });

    test('uses amountMinor when expense currency equals primary', () {
      // Expense is in USD, primary is USD — no conversion needed
      controller.add(_makeExpense(
        id: 'e1',
        amountMinor: 500,
        currencyCode: 'USD',
        amountInPrimary: null,
        primaryCurrencyCode: null,
      ));
      expect(controller.totalAllTime, 500);
    });

    test('falls back to live rates when primary changed', () {
      // Expense stored with EUR primary, but current primary is USD
      controller.add(_makeExpense(
        id: 'e1',
        amountMinor: 840,
        currencyCode: 'EUR',
        amountInPrimary: 840, // stored for EUR primary
        primaryCurrencyCode: 'EUR', // doesn't match current primary (USD)
      ));
      // Should use live conversion: 840 * (1/0.84) * 1.0 * (100/100) = 1000
      expect(controller.totalAllTime, 1000);
    });

    test('falls back to live rates when no stored conversion', () {
      // Build directly — _makeExpense defaults amountInPrimary to amountMinor
      controller.add(Expense(
        id: 'e1',
        amountMinor: 840,
        date: DateTime.now(),
        currencyCode: 'EUR',
      ));
      // Live conversion: 840 EUR cents → USD cents = 840 / 0.84 = 1000
      expect(controller.totalAllTime, 1000);
    });

    test('skips expenses with unsupported currencies', () {
      // Add a normal expense plus one with unsupported currency
      controller.add(_makeExpense(id: 'e1', amountMinor: 500));

      // Manually add to repo with unsupported currency, then reload
      expenseRepo.save(Expense(
        id: 'e2',
        amountMinor: 100,
        date: DateTime.now(),
        currencyCode: 'XYZ', // unsupported
      ));
      controller.reload();

      // Should include e1 (500) and skip e2 (unconvertible)
      expect(controller.totalAllTime, 500);
    });

    test('JPY to USD live conversion uses numToBasic scaling', () {
      // Build directly — _makeExpense defaults amountInPrimary to amountMinor
      controller.add(Expense(
        id: 'e1',
        amountMinor: 1530,
        date: DateTime.now(),
        currencyCode: 'JPY',
      ));
      // 1530 JPY → USD: 1530 * (1/153) * 1.0 * (100/1) = 1000
      expect(controller.totalAllTime, 1000);
    });
  });

  // ───────────────────────────────────────────────────────────────────────
  // Additional totals
  // ───────────────────────────────────────────────────────────────────────

  group('totals — comparison periods', () {
    test('totalLastWeek covers previous calendar week', () {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      // FakeSettingsRepository defaults to Monday start (DateTime.monday == 1)
      final daysFromWeekStart = (today.weekday - DateTime.monday + 7) % 7;
      final weekStart = today.subtract(Duration(days: daysFromWeekStart));
      // 3 days before weekStart is always within last week
      final lastWeekDate = weekStart.subtract(const Duration(days: 3));
      // 10 days before weekStart is always before last week (lastWeekStart = weekStart - 7)
      final twoWeeksAgo = weekStart.subtract(const Duration(days: 10));

      controller.add(_makeExpense(id: 'e1', amountMinor: 300, date: lastWeekDate));
      controller.add(_makeExpense(id: 'e2', amountMinor: 400, date: twoWeeksAgo));

      expect(controller.totalLastWeek, 300); // last week only, not two weeks ago
    });

    test('totalLastMonth covers previous calendar month', () {
      final now = DateTime.now();
      final lastMonthDate = DateTime(
        now.month == 1 ? now.year - 1 : now.year,
        now.month == 1 ? 12 : now.month - 1,
        15,
      );
      final twoMonthsAgo = DateTime(
        (now.month <= 2) ? now.year - 1 : now.year,
        (now.month <= 2) ? now.month + 10 : now.month - 2,
        15,
      );

      controller.add(_makeExpense(id: 'e1', amountMinor: 500, date: lastMonthDate));
      controller.add(_makeExpense(id: 'e2', amountMinor: 300, date: twoMonthsAgo));

      expect(controller.totalLastMonth, 500);
    });
  });

  group('averages — monthly', () {
    test('monthlyAverage divides by distinct months', () {
      final now = DateTime.now();
      final lastMonth = DateTime(
        now.month == 1 ? now.year - 1 : now.year,
        now.month == 1 ? 12 : now.month - 1,
        15,
      );

      controller.add(_makeExpense(id: 'e1', amountMinor: 600, date: now));
      controller.add(_makeExpense(id: 'e2', amountMinor: 400, date: lastMonth));

      // Total = 1000, 2 months → 500
      expect(controller.monthlyAverage, 500);
    });

    test('thisMonthDailyAverage uses days with expenses this month', () {
      final now = DateTime.now();
      final day1 = DateTime(now.year, now.month, 1);
      final day3 = DateTime(now.year, now.month, 3);

      controller.add(_makeExpense(id: 'e1', amountMinor: 300, date: day1));
      controller.add(_makeExpense(id: 'e2', amountMinor: 300, date: day3));

      // 2 days with expenses, total 600 → 300/day
      expect(controller.thisMonthDailyAverage, 300);
    });

    test('lastMonthDailyAverage uses days with expenses last month', () {
      final now = DateTime.now();
      final lastMonth1 = DateTime(
        now.month == 1 ? now.year - 1 : now.year,
        now.month == 1 ? 12 : now.month - 1,
        5,
      );
      final lastMonth2 = DateTime(
        now.month == 1 ? now.year - 1 : now.year,
        now.month == 1 ? 12 : now.month - 1,
        10,
      );

      controller.add(_makeExpense(id: 'e1', amountMinor: 200, date: lastMonth1));
      controller.add(_makeExpense(id: 'e2', amountMinor: 200, date: lastMonth2));

      // 2 days with expenses, total 400 → 200/day
      expect(controller.lastMonthDailyAverage, 200);
    });
  });

  // ───────────────────────────────────────────────────────────────────────
  // last7DayTotals (DailyTotal list)
  // ───────────────────────────────────────────────────────────────────────

  group('last7DayTotals', () {
    test('returns 7 entries covering last 7 calendar days', () {
      expect(controller.last7DayTotals.length, 7);
    });

    test('entries sorted by date ascending', () {
      final totals = controller.last7DayTotals;
      for (int i = 1; i < totals.length; i++) {
        expect(totals[i].date.isAfter(totals[i - 1].date), isTrue);
      }
    });

    test('sums amounts into correct day buckets', () {
      final today = DateTime.now();
      controller.add(_makeExpense(id: 'e1', amountMinor: 300, date: today));
      controller.add(_makeExpense(id: 'e2', amountMinor: 200, date: today));

      final todayTotal = controller.last7DayTotals.last;
      expect(todayTotal.totalMinor, 500);
    });
  });

  // ───────────────────────────────────────────────────────────────────────
  // Category/location totals lists
  // ───────────────────────────────────────────────────────────────────────

  group('category totals', () {
    test('topCategoryTotalsThisMonth sorted by amount descending', () {
      final now = DateTime.now();
      controller.add(_makeExpense(
          id: 'e1', amountMinor: 100, categoryId: 'cat-a', date: now));
      controller.add(_makeExpense(
          id: 'e2', amountMinor: 300, categoryId: 'cat-b', date: now));

      final totals = controller.topCategoryTotalsThisMonth;
      expect(totals.first.categoryId, 'cat-b');
      expect(totals.first.totalMinor, 300);
    });

    test('categoryTotalsThisWeek only includes current week expenses', () {
      final today = DateTime.now();
      final old = today.subtract(const Duration(days: 30));

      controller.add(_makeExpense(
          id: 'e1', amountMinor: 100, categoryId: 'cat-a', date: today));
      controller.add(_makeExpense(
          id: 'e2', amountMinor: 500, categoryId: 'cat-a', date: old));

      final totals = controller.categoryTotalsThisWeek;
      final catA = totals.where((t) => t.categoryId == 'cat-a').firstOrNull;
      expect(catA?.totalMinor, 100); // only this week
    });

    test('categoryTotalsAllTime includes all expenses', () {
      controller.add(_makeExpense(id: 'e1', amountMinor: 100, categoryId: 'cat-a'));
      controller.add(_makeExpense(id: 'e2', amountMinor: 200, categoryId: 'cat-a'));
      controller.add(_makeExpense(id: 'e3', amountMinor: 300, categoryId: 'cat-b'));

      final totals = controller.categoryTotalsAllTime;
      expect(totals.first.totalMinor, 300); // cat-a: 300 total
    });

    test('totalForCategory sums correctly', () {
      controller.add(_makeExpense(id: 'e1', amountMinor: 100, categoryId: 'cat-a'));
      controller.add(_makeExpense(id: 'e2', amountMinor: 200, categoryId: 'cat-a'));
      controller.add(_makeExpense(id: 'e3', amountMinor: 500, categoryId: 'cat-b'));

      expect(controller.totalForCategory('cat-a'), 300);
      expect(controller.totalForCategory('cat-b'), 500);
    });
  });

  group('location totals', () {
    test('locationTotalsAllTime sorted by amount descending', () {
      controller.add(_makeExpense(id: 'e1', amountMinor: 100, locationId: 'loc-a'));
      controller.add(_makeExpense(id: 'e2', amountMinor: 500, locationId: 'loc-b'));

      final totals = controller.locationTotalsAllTime;
      expect(totals.first.locationId, 'loc-b');
      expect(totals.first.totalMinor, 500);
    });

    test('totalForLocation sums correctly', () {
      controller.add(_makeExpense(id: 'e1', amountMinor: 100, locationId: 'loc-a'));
      controller.add(_makeExpense(id: 'e2', amountMinor: 200, locationId: 'loc-a'));

      expect(controller.totalForLocation('loc-a'), 300);
    });
  });

  // ───────────────────────────────────────────────────────────────────────
  // Category/location pagination
  // ───────────────────────────────────────────────────────────────────────

  group('category pagination', () {
    test('visibleForCategory respects page size', () {
      for (int i = 0; i < 40; i++) {
        controller.add(_makeExpense(
          id: 'e$i',
          categoryId: 'cat-a',
          date: DateTime(2025, 1, 1).add(Duration(days: i)),
        ));
      }

      expect(controller.visibleForCategory('cat-a').length, ExpenseController.pageSize);
      expect(controller.canLoadMoreForCategory('cat-a'), isTrue);
    });

    test('loadMoreForCategory increases visible count', () {
      for (int i = 0; i < 40; i++) {
        controller.add(_makeExpense(
          id: 'e$i',
          categoryId: 'cat-a',
          date: DateTime(2025, 1, 1).add(Duration(days: i)),
        ));
      }

      controller.loadMoreForCategory('cat-a');
      expect(controller.visibleForCategory('cat-a').length, 40);
      expect(controller.canLoadMoreForCategory('cat-a'), isFalse);
    });

    test('canLoadMoreForCategory returns false for small lists', () {
      controller.add(_makeExpense(id: 'e1', categoryId: 'cat-a'));
      expect(controller.canLoadMoreForCategory('cat-a'), isFalse);
    });

    test('visibleForCategory returns empty for unknown category', () {
      expect(controller.visibleForCategory('nonexistent'), isEmpty);
    });
  });

  group('location pagination', () {
    test('visibleForLocation respects page size', () {
      for (int i = 0; i < 40; i++) {
        controller.add(_makeExpense(
          id: 'e$i',
          locationId: 'loc-a',
          date: DateTime(2025, 1, 1).add(Duration(days: i)),
        ));
      }

      expect(controller.visibleForLocation('loc-a').length, ExpenseController.pageSize);
      expect(controller.canLoadMoreForLocation('loc-a'), isTrue);
    });

    test('loadMoreForLocation increases visible count', () {
      for (int i = 0; i < 40; i++) {
        controller.add(_makeExpense(
          id: 'e$i',
          locationId: 'loc-a',
          date: DateTime(2025, 1, 1).add(Duration(days: i)),
        ));
      }

      controller.loadMoreForLocation('loc-a');
      expect(controller.visibleForLocation('loc-a').length, 40);
    });
  });
}
