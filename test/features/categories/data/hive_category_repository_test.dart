import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:hive_test/hive_test.dart';
import 'package:spending_tracker_app/features/categories/data/hive_category_repository.dart';
import 'package:spending_tracker_app/features/categories/models/expense_category.dart';

ExpenseCategory _makeCategory({
  String id = 'cat-1',
  String name = 'Food',
  int colorValue = 0xFFFF5733,
  bool isActive = true,
}) {
  return ExpenseCategory(
    id: id,
    name: name,
    colorValue: colorValue,
    isActive: isActive,
  );
}

void main() {
  late Box box;
  late HiveCategoryRepository repo;

  setUp(() async {
    await setUpTestHive();
    box = await Hive.openBox('categories');
    repo = HiveCategoryRepository(box);
  });

  tearDown(() async => tearDownTestHive());

  group('save and getById', () {
    test('round-trips a category through Hive', () {
      final category = _makeCategory(id: 'cat-1', name: 'Transport', colorValue: 0xFF123456);
      repo.save(category);

      final retrieved = repo.getById('cat-1')!;
      expect(retrieved.id, 'cat-1');
      expect(retrieved.name, 'Transport');
      expect(retrieved.colorValue, 0xFF123456);
      expect(retrieved.isActive, isTrue);
    });

    test('returns null for unknown id', () {
      expect(repo.getById('nonexistent'), isNull);
    });

    test('overwriting same id updates the record', () {
      repo.save(_makeCategory(id: 'cat-1', name: 'Old Name'));
      repo.save(_makeCategory(id: 'cat-1', name: 'New Name'));

      expect(repo.getById('cat-1')!.name, 'New Name');
    });

    test('preserves isActive flag', () {
      repo.save(_makeCategory(id: 'cat-1', isActive: false));
      expect(repo.getById('cat-1')!.isActive, isFalse);
    });
  });

  group('getAll', () {
    test('returns all saved categories', () {
      repo.save(_makeCategory(id: 'cat-1', name: 'Food'));
      repo.save(_makeCategory(id: 'cat-2', name: 'Transport'));
      repo.save(_makeCategory(id: 'cat-3', name: 'Health'));

      expect(repo.getAll().length, 3);
    });

    test('skips corrupted entries without throwing', () {
      repo.save(_makeCategory(id: 'cat-1'));
      // Put a corrupted map directly — missing required 'colorValue' field
      box.put('bad', {'id': 'bad', 'name': 'Broken'});

      final all = repo.getAll();
      expect(all.length, 1);
      expect(all.first.id, 'cat-1');
    });

    test('returns empty list when box is empty', () {
      expect(repo.getAll(), isEmpty);
    });
  });

  group('delete', () {
    test('removes the category', () {
      repo.save(_makeCategory(id: 'cat-1'));
      repo.delete('cat-1');

      expect(repo.getById('cat-1'), isNull);
      expect(repo.getAll(), isEmpty);
    });

    test('no-ops for unknown id', () {
      repo.save(_makeCategory(id: 'cat-1'));
      repo.delete('nonexistent');

      expect(repo.getAll().length, 1);
    });
  });

  group('isEmpty', () {
    test('returns true when no categories saved', () {
      expect(repo.isEmpty(), isTrue);
    });

    test('returns false after saving a category', () {
      repo.save(_makeCategory());
      expect(repo.isEmpty(), isFalse);
    });

    test('returns true again after deleting all', () {
      repo.save(_makeCategory(id: 'cat-1'));
      repo.save(_makeCategory(id: 'cat-2'));
      repo.delete('cat-1');
      repo.delete('cat-2');

      expect(repo.isEmpty(), isTrue);
    });
  });
}
