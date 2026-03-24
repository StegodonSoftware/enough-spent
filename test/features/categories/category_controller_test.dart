import 'package:flutter_test/flutter_test.dart';
import 'package:spending_tracker_app/features/categories/category_controller.dart';
import 'package:spending_tracker_app/features/categories/models/expense_category.dart';
import 'package:spending_tracker_app/features/expenses/models/expense.dart';

import '../../helpers/fakes.dart';

void main() {
  late FakeCategoryRepository categoryRepo;
  late FakeExpenseRepository expenseRepo;
  late CategoryController controller;

  setUp(() {
    categoryRepo = FakeCategoryRepository();
    expenseRepo = FakeExpenseRepository();
    controller = CategoryController(categoryRepo, expenseRepo);
  });

  test('creates default categories when repository is empty', () {
    expect(controller.all.length, 7); // defaultCategoryNames has 7 entries
    expect(controller.all.every((c) => c.isActive), isTrue);
  });

  test('does not create defaults when repository has data', () {
    // Use fresh repos to avoid defaults from setUp's controller
    final freshCategoryRepo = FakeCategoryRepository();
    final freshExpenseRepo = FakeExpenseRepository();
    freshCategoryRepo.save(ExpenseCategory(
      id: 'existing',
      name: 'Existing',
      colorValue: 0xFF000000,
    ));
    final freshController = CategoryController(freshCategoryRepo, freshExpenseRepo);
    // Should only have the one we added (no defaults added)
    expect(freshController.all.length, 1);
  });

  group('addCategory', () {
    test('adds new category', () {
      final result = controller.addCategory('New Category', 0xFFFF0000);
      expect(result, isTrue);
      expect(controller.all.any((c) => c.name == 'New Category'), isTrue);
    });

    test('rejects empty name', () {
      expect(controller.addCategory('', null), isFalse);
      expect(controller.addCategory('   ', null), isFalse);
    });

    test('rejects duplicate name (case-insensitive)', () {
      controller.addCategory('Coffee', null);
      expect(controller.addCategory('coffee', null), isFalse);
      expect(controller.addCategory('COFFEE', null), isFalse);
    });

    test('rejects when at max categories', () {
      // Already have 7 defaults, add 3 more to reach max
      controller.addCategory('Cat 8', null);
      controller.addCategory('Cat 9', null);
      controller.addCategory('Cat 10', null);

      expect(controller.canAddCategory(), isFalse);
      expect(controller.addCategory('Cat 11', null), isFalse);
    });
  });

  group('get and getByName', () {
    test('get returns category by id', () {
      final first = controller.all.first;
      expect(controller.get(first.id), isNotNull);
      expect(controller.get(first.id)!.name, first.name);
    });

    test('get returns null for unknown id', () {
      expect(controller.get('nonexistent'), isNull);
    });

    test('getByName is case-insensitive', () {
      expect(controller.getByName('food'), isNotNull);
      expect(controller.getByName('FOOD'), isNotNull);
    });
  });

  group('update', () {
    test('updates existing category', () {
      final original = controller.all.first;
      controller.update(original.copyWith(name: 'Updated'));
      expect(controller.get(original.id)!.name, 'Updated');
    });
  });

  group('deleteCategory', () {
    test('deletes unused category', () {
      final category = controller.all.first;
      final result = controller.deleteCategory(category.id);
      expect(result.wasDeleted, isTrue);
      expect(controller.get(category.id), isNull);
    });

    test('deactivates category when used by expenses', () {
      final category = controller.all.first;
      expenseRepo.save(Expense(
        id: 'e1',
        amountMinor: 100,
        date: DateTime.now(),
        currencyCode: 'USD',
        categoryId: category.id,
      ));

      final result = controller.deleteCategory(category.id);
      expect(result.wasDeactivated, isTrue);
      expect(controller.get(category.id)!.isActive, isFalse);
    });

    test('returns none for non-existent category', () {
      final result = controller.deleteCategory('nonexistent');
      expect(result.wasDeleted, isFalse);
      expect(result.wasDeactivated, isFalse);
    });
  });

  group('active and inactive', () {
    test('filters correctly', () {
      final category = controller.all.first;
      controller.deleteCategory(category.id); // Will deactivate or delete

      // If unused, it's deleted. Let's create a used one first.
      expenseRepo.save(Expense(
        id: 'e1',
        amountMinor: 100,
        date: DateTime.now(),
        currencyCode: 'USD',
        categoryId: controller.all.first.id,
      ));
      controller.deleteCategory(controller.all.first.id);

      expect(controller.inactive.length, greaterThan(0));
      expect(controller.active.length, lessThan(controller.all.length));
    });
  });

  group('restore', () {
    test('restores deactivated category', () {
      final category = controller.all.first;
      expenseRepo.save(Expense(
        id: 'e1',
        amountMinor: 100,
        date: DateTime.now(),
        currencyCode: 'USD',
        categoryId: category.id,
      ));

      controller.deleteCategory(category.id);
      expect(controller.get(category.id)!.isActive, isFalse);

      controller.restore(category);
      expect(controller.get(category.id)!.isActive, isTrue);
    });
  });

  group('usageCount', () {
    test('returns correct count', () {
      final category = controller.all.first;
      expenseRepo.save(Expense(
        id: 'e1',
        amountMinor: 100,
        date: DateTime.now(),
        currencyCode: 'USD',
        categoryId: category.id,
      ));
      expenseRepo.save(Expense(
        id: 'e2',
        amountMinor: 200,
        date: DateTime.now(),
        currencyCode: 'USD',
        categoryId: category.id,
      ));

      expect(controller.usageCount(category.id), 2);
    });

    test('returns zero for unused category', () {
      expect(controller.usageCount('nonexistent'), 0);
    });
  });

  group('allUsageCounts', () {
    test('returns map with entry for every category', () {
      final counts = controller.allUsageCounts;
      expect(counts.keys, containsAll(controller.all.map((c) => c.id)));
    });

    test('reflects actual expense counts', () {
      final category = controller.all.first;
      expenseRepo.save(Expense(
        id: 'e1',
        amountMinor: 100,
        date: DateTime.now(),
        currencyCode: 'USD',
        categoryId: category.id,
      ));

      final counts = controller.allUsageCounts;
      expect(counts[category.id], 1);
    });

    test('unused categories have count zero', () {
      final counts = controller.allUsageCounts;
      expect(counts.values.every((c) => c == 0), isTrue);
    });
  });

  group('deleteCategory edge cases', () {
    test('deactivated category remains in all but not in active', () {
      final category = controller.all.first;
      expenseRepo.save(Expense(
        id: 'e1',
        amountMinor: 100,
        date: DateTime.now(),
        currencyCode: 'USD',
        categoryId: category.id,
      ));

      controller.deleteCategory(category.id);

      expect(controller.all.any((c) => c.id == category.id), isTrue);
      expect(controller.active.any((c) => c.id == category.id), isFalse);
      expect(controller.inactive.any((c) => c.id == category.id), isTrue);
    });

    test('deactivation persists to repository', () {
      final category = controller.all.first;
      expenseRepo.save(Expense(
        id: 'e1',
        amountMinor: 100,
        date: DateTime.now(),
        currencyCode: 'USD',
        categoryId: category.id,
      ));

      controller.deleteCategory(category.id);

      expect(categoryRepo.getById(category.id)!.isActive, isFalse);
    });

    test('deletion removes from repository', () {
      final category = controller.all.first;
      // Not used by any expense — will be hard deleted
      controller.deleteCategory(category.id);

      expect(categoryRepo.getById(category.id), isNull);
    });

    test('DeleteResult.deactivated carries the updated (inactive) category', () {
      final category = controller.all.first;
      expenseRepo.save(Expense(
        id: 'e1',
        amountMinor: 100,
        date: DateTime.now(),
        currencyCode: 'USD',
        categoryId: category.id,
      ));

      final result = controller.deleteCategory(category.id);

      expect(result.category!.isActive, isFalse);
    });

    test('canAddCategory is false at exactly maxCategories', () {
      // Defaults give 7; add 3 more to hit exactly 10
      controller.addCategory('Cat 8', null);
      controller.addCategory('Cat 9', null);
      controller.addCategory('Cat 10', null);

      expect(controller.all.length, CategoryController.maxCategories);
      expect(controller.canAddCategory(), isFalse);
    });

    test('canAddCategory is true one below maxCategories', () {
      // Defaults give 7; add 2 more → 9
      controller.addCategory('Cat 8', null);
      controller.addCategory('Cat 9', null);

      expect(controller.canAddCategory(), isTrue);
    });

    test('deactivated categories still count toward maxCategories', () {
      // Add up to max first
      controller.addCategory('Cat 8', null);
      controller.addCategory('Cat 9', null);
      controller.addCategory('Cat 10', null);

      // Deactivate one (must be used so it stays in the list)
      final last = controller.all.last;
      expenseRepo.save(Expense(
        id: 'e1',
        amountMinor: 100,
        date: DateTime.now(),
        currencyCode: 'USD',
        categoryId: last.id,
      ));
      controller.deleteCategory(last.id); // deactivates, stays in all

      // Still at max — cannot add
      expect(controller.all.length, CategoryController.maxCategories);
      expect(controller.canAddCategory(), isFalse);
    });
  });

  group('restore edge cases', () {
    test('restore adds category when not currently in list', () {
      final orphan = ExpenseCategory(
        id: 'orphan-1',
        name: 'Orphan',
        colorValue: 0xFF000000,
        isActive: false,
      );

      controller.restore(orphan);

      expect(controller.get('orphan-1'), isNotNull);
      expect(controller.get('orphan-1')!.isActive, isTrue);
    });
  });
}
