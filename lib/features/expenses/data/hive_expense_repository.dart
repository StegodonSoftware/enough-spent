import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import '../models/expense.dart';
import 'expense_repository.dart';

class HiveExpenseRepository implements ExpenseRepository {
  final Box _box;

  HiveExpenseRepository(this._box);

  @override
  List<Expense> getAll() {
    final expenses = <Expense>[];
    for (final entry in _box.values) {
      try {
        expenses.add(Expense.fromMap(Map.from(entry)));
      } catch (e) {
        debugPrint('HiveExpenseRepository: skipping corrupted expense entry: $e');
      }
    }
    expenses.sort((a, b) => b.date.compareTo(a.date));
    return expenses;
  }

  @override
  List<Expense> allSortedByDateDesc() {
    return getAll();
  }

  @override
  Expense? getById(String id) {
    final data = _box.get(id);
    if (data == null) return null;
    return Expense.fromMap(Map.from(data));
  }

  @override
  void save(Expense expense) {
    _box.put(expense.id, expense.toMap());
  }

  @override
  void delete(String id) {
    _box.delete(id);
  }

  @override
  void deleteAll() {
    _box.clear();
  }

  @override
  bool isCategoryUsed(String categoryId) {
    return _box.values.any((e) => e['categoryId'] == categoryId);
  }

  @override
  int countByCategory(String categoryId) {
    return _box.values.where((e) => e['categoryId'] == categoryId).length;
  }

  @override
  bool isLocationUsed(String locationId) {
    return _box.values.any((e) => e['locationId'] == locationId);
  }

  @override
  int countByLocation(String locationId) {
    return _box.values.where((e) => e['locationId'] == locationId).length;
  }

  @override
  Map<String, int> getLocationUsageCounts() {
    final counts = <String, int>{};
    for (final e in _box.values) {
      final locationId = e['locationId'] as String?;
      if (locationId != null && locationId.isNotEmpty) {
        counts[locationId] = (counts[locationId] ?? 0) + 1;
      }
    }
    return counts;
  }

  @override
  List<String> clearLocationFromExpenses(String locationId) {
    final affectedIds = <String>[];
    for (final key in _box.keys) {
      final data = _box.get(key);
      if (data != null && data['locationId'] == locationId) {
        final expense = Expense.fromMap(Map.from(data));
        save(expense.copyWith(clearLocationId: true));
        affectedIds.add(expense.id);
      }
    }
    return affectedIds;
  }

  @override
  List<String> updateLocationOnExpenses(String oldLocationId, String newLocationId) {
    final affectedIds = <String>[];
    for (final key in _box.keys) {
      final data = _box.get(key);
      if (data != null && data['locationId'] == oldLocationId) {
        final expense = Expense.fromMap(Map.from(data));
        save(expense.copyWith(locationId: newLocationId));
        affectedIds.add(expense.id);
      }
    }
    return affectedIds;
  }

  @override
  void restoreLocationOnExpenses(List<String> expenseIds, String locationId) {
    for (final id in expenseIds) {
      final data = _box.get(id);
      if (data != null) {
        final expense = Expense.fromMap(Map.from(data));
        save(expense.copyWith(locationId: locationId));
      }
    }
  }

  @override
  void saveBatch(List<Expense> expenses) {
    _box.putAll({for (final e in expenses) e.id: e.toMap()});
  }
}
