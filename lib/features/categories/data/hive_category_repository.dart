import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import '../models/expense_category.dart';
import 'category_repository.dart';

class HiveCategoryRepository implements CategoryRepository {
  final Box _box;

  HiveCategoryRepository(this._box);

  @override
  List<ExpenseCategory> getAll() {
    final categories = <ExpenseCategory>[];
    for (final entry in _box.values) {
      try {
        categories.add(ExpenseCategory.fromMap(Map.from(entry)));
      } catch (e) {
        debugPrint('HiveCategoryRepository: skipping corrupted category entry: $e');
      }
    }
    return categories;
  }

  @override
  ExpenseCategory? getById(String id) {
    final data = _box.get(id);
    if (data == null) return null;
    return ExpenseCategory.fromMap(Map.from(data));
  }

  @override
  void save(ExpenseCategory category) {
    _box.put(category.id, category.toMap());
  }

  @override
  void delete(String id) {
    _box.delete(id);
  }

  @override
  bool isEmpty() => _box.isEmpty;
}
