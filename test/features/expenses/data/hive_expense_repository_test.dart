import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:hive_test/hive_test.dart';
import 'package:spending_tracker_app/features/expenses/data/hive_expense_repository.dart';
import 'package:spending_tracker_app/features/expenses/models/expense.dart';

Expense _makeExpense({
  String id = 'exp-1',
  int amountMinor = 1000,
  String currencyCode = 'USD',
  DateTime? date,
  String? categoryId,
  String? locationId,
}) {
  return Expense(
    id: id,
    amountMinor: amountMinor,
    currencyCode: currencyCode,
    date: date ?? DateTime(2025, 6, 15),
    categoryId: categoryId,
    locationId: locationId,
  );
}

void main() {
  late Box box;
  late HiveExpenseRepository repo;

  setUp(() async {
    await setUpTestHive();
    box = await Hive.openBox('expenses');
    repo = HiveExpenseRepository(box);
  });

  tearDown(() async => tearDownTestHive());

  group('save and getById', () {
    test('round-trips an expense through Hive', () {
      final expense = _makeExpense(id: 'e1', amountMinor: 1500, currencyCode: 'EUR');
      repo.save(expense);

      final retrieved = repo.getById('e1')!;
      expect(retrieved.id, 'e1');
      expect(retrieved.amountMinor, 1500);
      expect(retrieved.currencyCode, 'EUR');
    });

    test('returns null for unknown id', () {
      expect(repo.getById('nonexistent'), isNull);
    });

    test('overwriting same id updates the record', () {
      repo.save(_makeExpense(id: 'e1', amountMinor: 100));
      repo.save(_makeExpense(id: 'e1', amountMinor: 999));

      expect(repo.getById('e1')!.amountMinor, 999);
    });
  });

  group('getAll', () {
    test('returns all saved expenses sorted by date descending', () {
      repo.save(_makeExpense(id: 'e1', date: DateTime(2025, 1, 10)));
      repo.save(_makeExpense(id: 'e2', date: DateTime(2025, 1, 20)));
      repo.save(_makeExpense(id: 'e3', date: DateTime(2025, 1, 5)));

      final all = repo.getAll();
      expect(all.map((e) => e.id).toList(), ['e2', 'e1', 'e3']);
    });

    test('skips corrupted entries without throwing', () {
      repo.save(_makeExpense(id: 'e1'));
      // Put a corrupted map directly — missing required 'currencyCode' field
      box.put('bad', {'id': 'bad', 'amountMinor': 100});

      final all = repo.getAll();
      expect(all.length, 1);
      expect(all.first.id, 'e1');
    });

    test('returns empty list when box is empty', () {
      expect(repo.getAll(), isEmpty);
    });
  });

  group('allSortedByDateDesc', () {
    test('delegates to getAll (same sort order)', () {
      repo.save(_makeExpense(id: 'e1', date: DateTime(2025, 3, 1)));
      repo.save(_makeExpense(id: 'e2', date: DateTime(2025, 1, 1)));

      final result = repo.allSortedByDateDesc();
      expect(result.first.id, 'e1');
    });
  });

  group('delete', () {
    test('removes the expense', () {
      repo.save(_makeExpense(id: 'e1'));
      repo.delete('e1');

      expect(repo.getById('e1'), isNull);
      expect(repo.getAll(), isEmpty);
    });

    test('no-ops for unknown id', () {
      repo.save(_makeExpense(id: 'e1'));
      repo.delete('nonexistent');

      expect(repo.getAll().length, 1);
    });
  });

  // deleteAll() delegates to box.clear() which is async (awaits disk IO before
  // clearing memory). The void interface cannot await it, so verification here
  // would be a timing race. Covered implicitly by integration tests.

  group('saveBatch', () {
    test('saves multiple expenses atomically', () {
      final expenses = [
        _makeExpense(id: 'e1', amountMinor: 100),
        _makeExpense(id: 'e2', amountMinor: 200),
        _makeExpense(id: 'e3', amountMinor: 300),
      ];
      repo.saveBatch(expenses);

      expect(repo.getAll().length, 3);
      expect(repo.getById('e2')!.amountMinor, 200);
    });
  });

  group('category queries', () {
    test('isCategoryUsed returns true when category is referenced', () {
      repo.save(_makeExpense(id: 'e1', categoryId: 'cat-1'));
      expect(repo.isCategoryUsed('cat-1'), isTrue);
    });

    test('isCategoryUsed returns false when no expense references category', () {
      repo.save(_makeExpense(id: 'e1', categoryId: 'cat-2'));
      expect(repo.isCategoryUsed('cat-1'), isFalse);
    });

    test('countByCategory counts correctly', () {
      repo.save(_makeExpense(id: 'e1', categoryId: 'cat-1'));
      repo.save(_makeExpense(id: 'e2', categoryId: 'cat-1'));
      repo.save(_makeExpense(id: 'e3', categoryId: 'cat-2'));

      expect(repo.countByCategory('cat-1'), 2);
      expect(repo.countByCategory('cat-2'), 1);
      expect(repo.countByCategory('cat-3'), 0);
    });
  });

  group('location queries', () {
    test('isLocationUsed returns true when location is referenced', () {
      repo.save(_makeExpense(id: 'e1', locationId: 'loc-1'));
      expect(repo.isLocationUsed('loc-1'), isTrue);
    });

    test('isLocationUsed returns false when no expense references location', () {
      repo.save(_makeExpense(id: 'e1', locationId: 'loc-2'));
      expect(repo.isLocationUsed('loc-1'), isFalse);
    });

    test('countByLocation counts correctly', () {
      repo.save(_makeExpense(id: 'e1', locationId: 'loc-1'));
      repo.save(_makeExpense(id: 'e2', locationId: 'loc-1'));
      repo.save(_makeExpense(id: 'e3', locationId: 'loc-2'));

      expect(repo.countByLocation('loc-1'), 2);
      expect(repo.countByLocation('loc-2'), 1);
      expect(repo.countByLocation('loc-3'), 0);
    });

    test('getLocationUsageCounts returns map of locationId to count', () {
      repo.save(_makeExpense(id: 'e1', locationId: 'loc-a'));
      repo.save(_makeExpense(id: 'e2', locationId: 'loc-a'));
      repo.save(_makeExpense(id: 'e3', locationId: 'loc-b'));
      repo.save(_makeExpense(id: 'e4')); // no location

      final counts = repo.getLocationUsageCounts();
      expect(counts['loc-a'], 2);
      expect(counts['loc-b'], 1);
      expect(counts.containsKey(''), isFalse); // null location not included
    });
  });

  group('clearLocationFromExpenses', () {
    test('clears locationId from matching expenses and returns their ids', () {
      repo.save(_makeExpense(id: 'e1', locationId: 'loc-1'));
      repo.save(_makeExpense(id: 'e2', locationId: 'loc-1'));
      repo.save(_makeExpense(id: 'e3', locationId: 'loc-2'));

      final affected = repo.clearLocationFromExpenses('loc-1');

      expect(affected, containsAll(['e1', 'e2']));
      expect(affected.length, 2);
      expect(repo.getById('e1')!.locationId, isNull);
      expect(repo.getById('e2')!.locationId, isNull);
      expect(repo.getById('e3')!.locationId, 'loc-2'); // unaffected
    });

    test('returns empty list when no matches', () {
      repo.save(_makeExpense(id: 'e1', locationId: 'loc-2'));
      expect(repo.clearLocationFromExpenses('loc-1'), isEmpty);
    });
  });

  group('updateLocationOnExpenses', () {
    test('replaces locationId on matching expenses', () {
      repo.save(_makeExpense(id: 'e1', locationId: 'loc-old'));
      repo.save(_makeExpense(id: 'e2', locationId: 'loc-old'));
      repo.save(_makeExpense(id: 'e3', locationId: 'loc-other'));

      final affected = repo.updateLocationOnExpenses('loc-old', 'loc-new');

      expect(affected, containsAll(['e1', 'e2']));
      expect(repo.getById('e1')!.locationId, 'loc-new');
      expect(repo.getById('e2')!.locationId, 'loc-new');
      expect(repo.getById('e3')!.locationId, 'loc-other'); // unaffected
    });
  });

  group('restoreLocationOnExpenses', () {
    test('restores locationId for given expense ids', () {
      repo.save(_makeExpense(id: 'e1'));
      repo.save(_makeExpense(id: 'e2'));

      repo.restoreLocationOnExpenses(['e1', 'e2'], 'loc-restored');

      expect(repo.getById('e1')!.locationId, 'loc-restored');
      expect(repo.getById('e2')!.locationId, 'loc-restored');
    });

    test('ignores ids that do not exist', () {
      repo.save(_makeExpense(id: 'e1'));
      // Should not throw for unknown id
      repo.restoreLocationOnExpenses(['e1', 'nonexistent'], 'loc-x');

      expect(repo.getById('e1')!.locationId, 'loc-x');
    });
  });
}
