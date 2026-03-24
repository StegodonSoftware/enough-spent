import 'package:flutter_test/flutter_test.dart';
import 'package:spending_tracker_app/features/categories/models/expense_category.dart';

ExpenseCategory _makeCategory({
  String id = 'cat-1',
  String name = 'Food',
  int colorValue = 0xFF4CAF50,
  bool isActive = true,
}) {
  return ExpenseCategory(
    id: id,
    name: name,
    colorValue: colorValue,
    isActive: isActive,
    createdAt: DateTime(2025, 1, 1),
    updatedAt: DateTime(2025, 1, 1),
  );
}

void main() {
  group('validate', () {
    test('valid category returns no errors', () {
      expect(_makeCategory().validate(), isEmpty);
      expect(_makeCategory().isValid, isTrue);
    });

    test('empty id is invalid', () {
      final cat = _makeCategory(id: '');
      expect(cat.validate(), contains('Category ID cannot be empty'));
    });

    test('whitespace-only id is invalid', () {
      final cat = _makeCategory(id: '   ');
      expect(cat.validate(), isNotEmpty);
    });

    test('empty name is invalid', () {
      final cat = _makeCategory(name: '');
      expect(cat.validate(), contains('Category name cannot be empty'));
    });

    test('name exceeding max length is invalid', () {
      final longName = 'x' * (ExpenseCategory.maxNameLength + 1);
      final cat = _makeCategory(name: longName);
      expect(cat.validate(), isNotEmpty);
    });

    test('name at max length is valid', () {
      final maxName = 'x' * ExpenseCategory.maxNameLength;
      final cat = _makeCategory(name: maxName);
      expect(cat.validate(), isEmpty);
    });
  });

  group('copyWith', () {
    test('returns new instance with updated fields', () {
      final original = _makeCategory();
      final copy = original.copyWith(name: 'Transport', isActive: false);
      expect(copy.name, 'Transport');
      expect(copy.isActive, isFalse);
      expect(copy.id, original.id);
      expect(copy.colorValue, original.colorValue);
    });

    test('preserves createdAt', () {
      final original = _makeCategory();
      final copy = original.copyWith(name: 'New');
      expect(copy.createdAt, original.createdAt);
    });
  });

  group('toMap / fromMap', () {
    test('round-trips correctly', () {
      final original = _makeCategory(isActive: false);
      final map = original.toMap();
      final restored = ExpenseCategory.fromMap(map);

      expect(restored.id, original.id);
      expect(restored.name, original.name);
      expect(restored.colorValue, original.colorValue);
      expect(restored.isActive, original.isActive);
    });

    test('throws on missing id', () {
      expect(
        () => ExpenseCategory.fromMap({'name': 'Food', 'colorValue': 0xFF000000}),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('throws on missing name', () {
      expect(
        () => ExpenseCategory.fromMap({'id': 'x', 'colorValue': 0xFF000000}),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('throws on missing colorValue', () {
      expect(
        () => ExpenseCategory.fromMap({'id': 'x', 'name': 'Food'}),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('defaults isActive to true when missing', () {
      final cat = ExpenseCategory.fromMap({
        'id': 'x',
        'name': 'Food',
        'colorValue': 0xFF000000,
      });
      expect(cat.isActive, isTrue);
    });
  });

  test('color getter returns Color from colorValue', () {
    final cat = _makeCategory(colorValue: 0xFF4CAF50);
    expect(cat.color.toARGB32(), 0xFF4CAF50);
  });
}
