import 'package:spending_tracker_app/features/expenses/data/expense_repository.dart';
import 'package:spending_tracker_app/features/expenses/models/expense.dart';
import 'package:spending_tracker_app/features/categories/data/category_repository.dart';
import 'package:spending_tracker_app/features/categories/models/expense_category.dart';
import 'package:spending_tracker_app/features/locations/data/location_repository.dart';
import 'package:spending_tracker_app/features/locations/models/location.dart';
import 'package:spending_tracker_app/features/settings/data/settings_repository.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Fake Expense Repository
// ─────────────────────────────────────────────────────────────────────────────

class FakeExpenseRepository implements ExpenseRepository {
  final Map<String, Expense> _store = {};

  @override
  List<Expense> getAll() => _store.values.toList();

  @override
  List<Expense> allSortedByDateDesc() {
    final list = _store.values.toList();
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  @override
  Expense? getById(String id) => _store[id];

  @override
  void save(Expense expense) => _store[expense.id] = expense;

  @override
  void delete(String id) => _store.remove(id);

  @override
  void deleteAll() => _store.clear();

  @override
  bool isCategoryUsed(String categoryId) =>
      _store.values.any((e) => e.categoryId == categoryId);

  @override
  int countByCategory(String categoryId) =>
      _store.values.where((e) => e.categoryId == categoryId).length;

  @override
  bool isLocationUsed(String locationId) =>
      _store.values.any((e) => e.locationId == locationId);

  @override
  int countByLocation(String locationId) =>
      _store.values.where((e) => e.locationId == locationId).length;

  @override
  Map<String, int> getLocationUsageCounts() {
    final counts = <String, int>{};
    for (final e in _store.values) {
      if (e.locationId != null) {
        counts.update(e.locationId!, (v) => v + 1, ifAbsent: () => 1);
      }
    }
    return counts;
  }

  @override
  List<String> clearLocationFromExpenses(String locationId) {
    final affected = <String>[];
    for (final e in _store.values.toList()) {
      if (e.locationId == locationId) {
        _store[e.id] = e.copyWith(clearLocationId: true);
        affected.add(e.id);
      }
    }
    return affected;
  }

  @override
  List<String> updateLocationOnExpenses(
      String oldLocationId, String newLocationId) {
    final affected = <String>[];
    for (final e in _store.values.toList()) {
      if (e.locationId == oldLocationId) {
        _store[e.id] = e.copyWith(locationId: newLocationId);
        affected.add(e.id);
      }
    }
    return affected;
  }

  @override
  void restoreLocationOnExpenses(List<String> expenseIds, String locationId) {
    for (final id in expenseIds) {
      final e = _store[id];
      if (e != null) {
        _store[id] = e.copyWith(locationId: locationId);
      }
    }
  }

  @override
  void saveBatch(List<Expense> expenses) {
    for (final e in expenses) {
      _store[e.id] = e;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Fake Category Repository
// ─────────────────────────────────────────────────────────────────────────────

class FakeCategoryRepository implements CategoryRepository {
  final Map<String, ExpenseCategory> _store = {};

  @override
  List<ExpenseCategory> getAll() => _store.values.toList();

  @override
  ExpenseCategory? getById(String id) => _store[id];

  @override
  void save(ExpenseCategory category) => _store[category.id] = category;

  @override
  void delete(String id) => _store.remove(id);

  @override
  bool isEmpty() => _store.isEmpty;
}

// ─────────────────────────────────────────────────────────────────────────────
// Fake Location Repository
// ─────────────────────────────────────────────────────────────────────────────

class FakeLocationRepository implements LocationRepository {
  final Map<String, Location> _store = {};

  @override
  List<Location> getAll() => _store.values.toList();

  @override
  Location? getById(String id) => _store[id];

  @override
  Location? getByName(String name) {
    final lower = name.toLowerCase();
    try {
      return _store.values.firstWhere(
        (l) => l.name.toLowerCase() == lower,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  void save(Location location) => _store[location.id] = location;

  @override
  void delete(String id) => _store.remove(id);

  @override
  bool isEmpty() => _store.isEmpty;
}

// ─────────────────────────────────────────────────────────────────────────────
// Fake Settings Repository
// ─────────────────────────────────────────────────────────────────────────────

class FakeSettingsRepository implements SettingsRepository {
  String _primaryCurrency = 'USD';
  List<String> _recentCurrencies = [];
  int _firstDayOfWeek = 1; // Monday
  bool _isOnboarded = true;
  String? _lockedCurrencyCode;
  bool _conversionInProgress = false;

  FakeSettingsRepository({
    String primaryCurrency = 'USD',
    List<String>? recentCurrencies,
    bool conversionInProgress = false,
  })  : _primaryCurrency = primaryCurrency,
        _recentCurrencies = recentCurrencies ?? [],
        _conversionInProgress = conversionInProgress;

  @override
  String getPrimaryCurrency() => _primaryCurrency;

  @override
  void setPrimaryCurrency(String currencyCode) =>
      _primaryCurrency = currencyCode;

  @override
  List<String> getRecentCurrencies() => _recentCurrencies.toList();

  @override
  void saveRecentCurrencies(List<String> codes) =>
      _recentCurrencies = codes.toList();

  @override
  int getFirstDayOfWeek() => _firstDayOfWeek;

  @override
  void setFirstDayOfWeek(int weekday) => _firstDayOfWeek = weekday;

  @override
  bool isOnboarded() => _isOnboarded;

  @override
  void setOnboarded(bool value) => _isOnboarded = value;

  @override
  String? getLockedCurrencyCode() => _lockedCurrencyCode;

  @override
  void setLockedCurrencyCode(String? currencyCode) =>
      _lockedCurrencyCode = currencyCode;

  @override
  bool getConversionInProgress() => _conversionInProgress;

  @override
  void setConversionInProgress(bool value) => _conversionInProgress = value;
}
