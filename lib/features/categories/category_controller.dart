import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../core/theme/app_colors.dart';
import 'data/category_repository.dart';
import 'models/expense_category.dart';
import '../expenses/data/expense_repository.dart';
import 'models/category_delete_result.dart';

class CategoryController extends ChangeNotifier {
  final CategoryRepository _categories;
  final ExpenseRepository _expenses;

  late List<ExpenseCategory> _all;

  static const int maxCategories = 10;
  static const _uuid = Uuid();

  CategoryController(this._categories, this._expenses) {
    _all = _categories.getAll();
    _ensureDefaults();
  }

  void _ensureDefaults() {
    if (_all.isNotEmpty) return;

    final defaults = [
      for (final c in defaultCategoryNames.asMap().entries)
        ExpenseCategory(
          id: _uuid.v4(),
          name: c.value,
          colorValue: AppColors.defaultCategoryPalette[c.key % AppColors.defaultCategoryPalette.length]
              .toARGB32(),
        ),
    ];

    _all = defaults;
    for (final c in defaults) {
      _categories.save(c);
    }
  }

  List<ExpenseCategory> get all => _all.toList();

  List<ExpenseCategory> get active => _all.where((c) => c.isActive).toList();

  List<ExpenseCategory> get inactive => _all.where((c) => !c.isActive).toList();

  ExpenseCategory? get(String id) {
    for (final category in _all) {
      if (category.id == id) return category;
    }
    return null;
  }

  /// Finds a category by name (case-insensitive).
  ExpenseCategory? getByName(String name) {
    final lowerName = name.toLowerCase();
    for (final category in _all) {
      if (category.name.toLowerCase() == lowerName) return category;
    }
    return null;
  }

  void update(ExpenseCategory category) {
    _categories.save(category);
    final index = _all.indexWhere((c) => c.id == category.id);
    if (index != -1) {
      _all[index] = category;
    } else {
      _all.add(category);
    }
    notifyListeners();
  }

  /// Adds a new category. Returns false if:
  /// - Max categories reached
  /// - Name is empty
  /// - Name already exists (case-insensitive)
  bool addCategory(String name, int? colorValue) {
    if (!canAddCategory()) return false;

    final trimmed = name.trim();
    if (trimmed.isEmpty) return false;

    // Check for duplicate names (case-insensitive)
    final lowerName = trimmed.toLowerCase();
    final isDuplicate = _all.any((c) => c.name.toLowerCase() == lowerName);
    if (isDuplicate) return false;

    final category = ExpenseCategory(
      id: _uuid.v4(),
      name: trimmed,
      isActive: true,
      colorValue:
          colorValue ??
          AppColors.defaultCategoryPalette[_all.length % AppColors.defaultCategoryPalette.length].toARGB32(),
    );

    _categories.save(category);
    _all.add(category);
    notifyListeners();
    return true;
  }

  void restore(ExpenseCategory category) {
    final index = _all.indexWhere((c) => c.id == category.id);

    if (index == -1) {
      _all.add(category.copyWith(isActive: true));
    } else {
      _all[index] = category.copyWith(isActive: true);
    }

    _categories.save(category.copyWith(isActive: true));
    notifyListeners();
  }

  DeleteResult deleteCategory(String id) {
    final index = _all.indexWhere((c) => c.id == id);
    if (index == -1) return DeleteResult.none();

    final category = _all[index];
    final isUsed = _expenses.isCategoryUsed(id);

    if (!isUsed) {
      _all.removeAt(index);
      _categories.delete(id);
      notifyListeners();
      return DeleteResult.deleted(category);
    } else {
      final updated = category.copyWith(isActive: false);
      _all[index] = updated;
      _categories.save(updated);
      notifyListeners();
      return DeleteResult.deactivated(updated);
    }
  }

  int usageCount(String categoryId) {
    return _expenses.countByCategory(categoryId);
  }

  /// Returns a map of category ID to usage count for all categories.
  Map<String, int> get allUsageCounts {
    return {for (final c in _all) c.id: _expenses.countByCategory(c.id)};
  }

  bool canAddCategory() {
    return _all.length < maxCategories;
  }
}
