import 'package:flutter_test/flutter_test.dart';
import 'package:spending_tracker_app/features/categories/models/category_delete_result.dart';
import 'package:spending_tracker_app/features/categories/models/expense_category.dart';

ExpenseCategory _makeCategory({String id = 'cat-1', String name = 'Food'}) =>
    ExpenseCategory(id: id, name: name, colorValue: 0xFF000000);

void main() {
  group('DeleteResult.deleted', () {
    test('wasDeleted is true', () {
      final result = DeleteResult.deleted(_makeCategory());
      expect(result.wasDeleted, isTrue);
    });

    test('wasDeactivated is false', () {
      final result = DeleteResult.deleted(_makeCategory());
      expect(result.wasDeactivated, isFalse);
    });

    test('holds the category', () {
      final cat = _makeCategory(id: 'cat-1', name: 'Food');
      final result = DeleteResult.deleted(cat);
      expect(result.category?.id, 'cat-1');
      expect(result.category?.name, 'Food');
    });
  });

  group('DeleteResult.deactivated', () {
    test('wasDeactivated is true', () {
      final result = DeleteResult.deactivated(_makeCategory());
      expect(result.wasDeactivated, isTrue);
    });

    test('wasDeleted is false', () {
      final result = DeleteResult.deactivated(_makeCategory());
      expect(result.wasDeleted, isFalse);
    });

    test('holds the category', () {
      final cat = _makeCategory(id: 'cat-2', name: 'Transport');
      final result = DeleteResult.deactivated(cat);
      expect(result.category?.id, 'cat-2');
    });
  });

  group('DeleteResult.none', () {
    test('wasDeleted is false', () {
      expect(DeleteResult.none().wasDeleted, isFalse);
    });

    test('wasDeactivated is false', () {
      expect(DeleteResult.none().wasDeactivated, isFalse);
    });

    test('category is null', () {
      expect(DeleteResult.none().category, isNull);
    });
  });
}
