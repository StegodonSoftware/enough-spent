import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/currency/currency_service.dart';
import '../categories/data/category_repository.dart';
import '../locations/data/location_repository.dart';
import '../settings/settings_controller.dart';
import 'data/expense_repository.dart';
import 'models/expense.dart';
import 'models/expense_totals.dart';

/// Manages expense data with lazy computation and caching.
///
/// Uses dirty flags to avoid unnecessary recalculations. Computed properties
/// are only recalculated when the underlying data changes.
class ExpenseController extends ChangeNotifier {
  static const int pageSize = 30;

  final ExpenseRepository _repository;
  final CategoryRepository _categories;
  final LocationRepository _locations;
  final CurrencyService _currencyService;
  final SettingsController _settings;

  // Core data
  List<Expense> _all = [];
  int _visibleCount = pageSize;

  // Dirty flags for lazy computation
  bool _totalsNeedRecalc = true;
  bool _categoryDataNeedRecalc = true;
  bool _locationDataNeedRecalc = true;

  // Cached totals (lazily computed)
  int _totalToday = 0;
  int _totalThisWeek = 0;
  int _totalThisMonth = 0;
  int _totalAllTime = 0;
  int _totalLastWeek = 0;
  int _totalLastMonth = 0;
  int _dailyAverage = 0;
  int _weeklyAverage = 0;
  int _thisMonthDailyAverage = 0;
  int _lastMonthDailyAverage = 0;
  int _monthlyAverage = 0;
  DateTime? _firstExpenseDate;
  List<DailyTotal> _last7DayTotals = [];
  List<CategoryTotal> _categoryTotalsThisMonth = [];
  List<CategoryTotal> _categoryTotalsThisWeek = [];
  List<LocationTotal> _locationTotalsThisMonth = [];
  List<LocationTotal> _locationTotalsThisWeek = [];
  Map<DateTime, int> _dailyTotalsMinor = {};
  Map<String, int> _categoryTotalsMinor = {};

  // Cached category grouping (lazily computed)
  Map<String, List<Expense>> _expensesByCategory = {};
  List<String> _orderedCategoryIds = [];

  // Cached location grouping (lazily computed)
  Map<String, List<Expense>> _expensesByLocation = {};
  List<String> _orderedLocationIds = [];

  // Per-category pagination state
  final Map<String, int> _visibleByCategory = {};

  // Per-location pagination state
  final Map<String, int> _visibleByLocation = {};

  // Pending soft-delete state (deferred persistence for undo support)
  Expense? _pendingDelete;
  Timer? _pendingDeleteTimer;

  // How long to wait before committing a soft-delete to storage.
  // Slightly longer than the toast duration (4s) to ensure the undo
  // button is gone before the data is permanently removed.
  static const _undoWindow = Duration(seconds: 5);

  ExpenseController(
    this._repository,
    this._categories,
    this._locations,
    this._currencyService,
    this._settings,
  ) {
    _load();
  }

  void _load() {
    _all = _repository.allSortedByDateDesc().toList();
    _invalidateAll();
    notifyListeners();
  }

  void _invalidateAll() {
    _totalsNeedRecalc = true;
    _categoryDataNeedRecalc = true;
    _locationDataNeedRecalc = true;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Public API: Core Data Access
  // ─────────────────────────────────────────────────────────────────────────

  /// All expenses, sorted by date descending (read-only).
  List<Expense> get all => List.unmodifiable(_all);

  /// Paginated slice of expenses for the main list view.
  List<Expense> get visibleExpenses =>
      _all.take(_visibleCount).toList(growable: false);

  /// Whether more expenses can be loaded via [loadMore].
  bool get canLoadMore => _visibleCount < _all.length;

  /// Load the next page of expenses.
  void loadMore() {
    if (!canLoadMore) return;
    _visibleCount = (_visibleCount + pageSize).clamp(0, _all.length);
    notifyListeners();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Public API: CRUD Operations
  // ─────────────────────────────────────────────────────────────────────────

  void add(Expense expense) {
    final errors = expense.validate();
    assert(errors.isEmpty, 'Invalid expense: ${errors.join(', ')}');
    if (errors.isNotEmpty) {
      debugPrint('ExpenseController.add: Invalid expense: ${errors.join(', ')}');
      return;
    }

    _all.add(expense);
    _sortByDateDesc();
    _repository.save(expense);
    _onDataChanged();
  }

  void update(Expense updated) {
    final errors = updated.validate();
    assert(errors.isEmpty, 'Invalid expense: ${errors.join(', ')}');
    if (errors.isNotEmpty) {
      debugPrint('ExpenseController.update: Invalid expense: ${errors.join(', ')}');
      return;
    }

    final index = _all.indexWhere((e) => e.id == updated.id);
    if (index == -1) return;

    _all[index] = updated;
    _sortByDateDesc();
    _repository.save(updated);
    _onDataChanged();
  }

  Expense? delete(String id) {
    final index = _all.indexWhere((e) => e.id == id);
    if (index == -1) return null;

    final removed = _all.removeAt(index);
    _repository.delete(id);
    _onDataChanged();
    return removed;
  }

  /// Removes an expense from the in-memory list immediately (so the UI
  /// updates at once) but defers the Hive write until [_undoWindow] elapses.
  ///
  /// If a previous soft-delete is still pending it is committed to storage
  /// first, so only one undo slot exists at a time — matching the single
  /// undo toast that can be on screen.
  ///
  /// Call [restorePendingDelete] to undo within the window.
  void softDelete(String id) {
    _commitPendingDelete(); // flush any previous pending delete first

    final index = _all.indexWhere((e) => e.id == id);
    if (index == -1) return;

    _pendingDelete = _all.removeAt(index);
    _pendingDeleteTimer = Timer(_undoWindow, _commitPendingDelete);
    _onDataChanged();
  }

  /// Cancels the pending soft-delete and restores the expense to the list.
  ///
  /// Safe to call when no delete is pending (no-op).
  void restorePendingDelete() {
    if (_pendingDelete == null) return;

    _pendingDeleteTimer?.cancel();
    _pendingDeleteTimer = null;

    _all.add(_pendingDelete!);
    _pendingDelete = null;
    _sortByDateDesc();
    _onDataChanged();
  }

  void _commitPendingDelete() {
    _pendingDeleteTimer?.cancel();
    _pendingDeleteTimer = null;

    if (_pendingDelete != null) {
      _repository.delete(_pendingDelete!.id);
      _pendingDelete = null;
    }
  }

  /// Deletes all expenses. Use with caution - intended for debug/testing.
  void clearAll() {
    _all.clear();
    _repository.deleteAll();
    _visibleCount = pageSize;
    _onDataChanged();
  }

  @override
  void dispose() {
    _commitPendingDelete();
    super.dispose();
  }

  /// Reloads all expenses from the repository.
  /// Use when external code modifies expenses directly
  /// (e.g., currency conversion, cascade deletes).
  void reload() {
    _load();
  }

  /// Marks all cached totals as stale and triggers a rebuild.
  /// Use when returning from background to pick up date boundary changes.
  void invalidateTotals() {
    _invalidateAll();
    notifyListeners();
  }

  void _onDataChanged() {
    _invalidateAll();
    _visibleByCategory.clear();
    _visibleByLocation.clear();
    notifyListeners();
  }

  void _sortByDateDesc() {
    _all.sort((a, b) => b.date.compareTo(a.date));
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Public API: Category-Based Access
  // ─────────────────────────────────────────────────────────────────────────

  /// Expenses grouped by category ID, each list sorted by date descending.
  Map<String, List<Expense>> get expensesByCategory {
    _ensureCategoryDataComputed();
    return Map.unmodifiable(_expensesByCategory);
  }

  /// Category IDs ordered by expense count (most used first).
  List<String> get orderedCategoryIds {
    _ensureCategoryDataComputed();
    return List.unmodifiable(_orderedCategoryIds);
  }

  /// Paginated expenses for a specific category.
  List<Expense> visibleForCategory(String categoryId) {
    _ensureCategoryDataComputed();
    final allForCategory = _expensesByCategory[categoryId] ?? [];
    final visibleCount = _visibleByCategory[categoryId] ?? pageSize;
    return allForCategory.take(visibleCount).toList(growable: false);
  }

  /// Whether more expenses can be loaded for a category.
  bool canLoadMoreForCategory(String categoryId) {
    _ensureCategoryDataComputed();
    final total = _expensesByCategory[categoryId]?.length ?? 0;
    final visible = _visibleByCategory[categoryId] ?? pageSize;
    return visible < total;
  }

  /// Load the next page of expenses for a category.
  void loadMoreForCategory(String categoryId) {
    _ensureCategoryDataComputed();
    final current = _visibleByCategory[categoryId] ?? pageSize;
    final total = _expensesByCategory[categoryId]?.length ?? 0;

    if (current >= total) return;

    _visibleByCategory[categoryId] = (current + pageSize).clamp(0, total);
    notifyListeners();
  }

  /// Check if any expenses use the given category.
  bool isCategoryUsed(String categoryId) {
    return _all.any((e) => e.categoryId == categoryId);
  }

  /// Total amount (in minor units) for a specific category across all time.
  int totalForCategory(String categoryId) {
    _ensureCategoryDataComputed();
    final expenses = _expensesByCategory[categoryId] ?? [];
    return expenses.fold(0, (sum, e) => sum + (_convertToPrimary(e) ?? 0));
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Public API: Location-Based Access
  // ─────────────────────────────────────────────────────────────────────────

  /// Expenses grouped by location ID, each list sorted by date descending.
  Map<String, List<Expense>> get expensesByLocation {
    _ensureLocationDataComputed();
    return Map.unmodifiable(_expensesByLocation);
  }

  /// Location IDs ordered by expense count (most used first).
  List<String> get orderedLocationIds {
    _ensureLocationDataComputed();
    return List.unmodifiable(_orderedLocationIds);
  }

  /// Paginated expenses for a specific location.
  List<Expense> visibleForLocation(String locationId) {
    _ensureLocationDataComputed();
    final allForLocation = _expensesByLocation[locationId] ?? [];
    final visibleCount = _visibleByLocation[locationId] ?? pageSize;
    return allForLocation.take(visibleCount).toList(growable: false);
  }

  /// Whether more expenses can be loaded for a location.
  bool canLoadMoreForLocation(String locationId) {
    _ensureLocationDataComputed();
    final total = _expensesByLocation[locationId]?.length ?? 0;
    final visible = _visibleByLocation[locationId] ?? pageSize;
    return visible < total;
  }

  /// Load the next page of expenses for a location.
  void loadMoreForLocation(String locationId) {
    _ensureLocationDataComputed();
    final current = _visibleByLocation[locationId] ?? pageSize;
    final total = _expensesByLocation[locationId]?.length ?? 0;

    if (current >= total) return;

    _visibleByLocation[locationId] = (current + pageSize).clamp(0, total);
    notifyListeners();
  }

  /// Total amount (in minor units) for a specific location across all time.
  int totalForLocation(String locationId) {
    _ensureLocationDataComputed();
    final expenses = _expensesByLocation[locationId] ?? [];
    return expenses.fold(0, (sum, e) => sum + (_convertToPrimary(e) ?? 0));
  }

  /// Total amount (in primary currency minor units) for an arbitrary list of expenses.
  ///
  /// Useful for screen-level groupings the controller doesn't own (e.g. date
  /// period groups), where the screen supplies the expense list and the
  /// controller handles currency conversion via [_convertToPrimary].
  int totalForExpenses(Iterable<Expense> expenses) =>
      expenses.fold(0, (sum, e) => sum + (_convertToPrimary(e) ?? 0));

  // ─────────────────────────────────────────────────────────────────────────
  // Public API: Totals & Analytics
  // ─────────────────────────────────────────────────────────────────────────

  int get totalToday {
    _ensureTotalsComputed();
    return _totalToday;
  }

  int get totalThisWeek {
    _ensureTotalsComputed();
    return _totalThisWeek;
  }

  int get totalThisMonth {
    _ensureTotalsComputed();
    return _totalThisMonth;
  }

  int get totalAllTime {
    _ensureTotalsComputed();
    return _totalAllTime;
  }

  int get totalLastWeek {
    _ensureTotalsComputed();
    return _totalLastWeek;
  }

  int get totalLastMonth {
    _ensureTotalsComputed();
    return _totalLastMonth;
  }

  int get dailyAverage {
    _ensureTotalsComputed();
    return _dailyAverage;
  }

  int get weeklyAverage {
    _ensureTotalsComputed();
    return _weeklyAverage;
  }

  int get thisMonthDailyAverage {
    _ensureTotalsComputed();
    return _thisMonthDailyAverage;
  }

  int get lastMonthDailyAverage {
    _ensureTotalsComputed();
    return _lastMonthDailyAverage;
  }

  int get monthlyAverage {
    _ensureTotalsComputed();
    return _monthlyAverage;
  }

  DateTime? get firstExpenseDate {
    _ensureTotalsComputed();
    return _firstExpenseDate;
  }

  /// Comparison of today's spending against the all-time daily average.
  SpendingComparison get todayComparison {
    _ensureTotalsComputed();
    return _buildComparison(_totalToday, _dailyAverage, 'vs avg', 'Same as avg');
  }

  /// Comparison of this week's spending against last week.
  SpendingComparison get thisWeekComparison {
    _ensureTotalsComputed();
    return _buildComparison(_totalThisWeek, _totalLastWeek, 'vs last week', 'Same as last week');
  }

  /// Comparison of this month's daily average against last month's daily average.
  SpendingComparison get thisMonthDailyAvgComparison {
    _ensureTotalsComputed();
    return _buildComparison(
      _thisMonthDailyAverage,
      _lastMonthDailyAverage,
      'daily avg vs last month',
      'Same daily avg as last month',
    );
  }

  SpendingComparison _buildComparison(
    int current,
    int baseline,
    String changeLabel,
    String neutralText,
  ) {
    if (baseline <= 0) return const SpendingComparison();
    final diff = current - baseline;
    if (diff == 0) return SpendingComparison(text: neutralText, isPositive: null);
    final percent = ((diff.abs() / baseline) * 100).round();
    final arrow = diff < 0 ? '\u2193' : '\u2191';
    return SpendingComparison(
      text: '$arrow$percent% $changeLabel',
      isPositive: diff < 0,
    );
  }

  List<DailyTotal> get last7DayTotals {
    _ensureTotalsComputed();
    return List.unmodifiable(_last7DayTotals);
  }

  List<CategoryTotal> get topCategoryTotalsThisMonth {
    _ensureTotalsComputed();
    return List.unmodifiable(_categoryTotalsThisMonth);
  }

  Map<DateTime, int> get dailyTotalsMinor {
    _ensureTotalsComputed();
    return Map.unmodifiable(_dailyTotalsMinor);
  }

  Map<String, int> get categoryTotalsMinor {
    _ensureTotalsComputed();
    return Map.unmodifiable(_categoryTotalsMinor);
  }

  /// Category totals for this week, sorted by amount descending.
  List<CategoryTotal> get categoryTotalsThisWeek {
    _ensureTotalsComputed();
    return List.unmodifiable(_categoryTotalsThisWeek);
  }

  /// Category IDs sorted alphabetically by category name.
  List<String> get categoryIdsSortedAlphabetically {
    _ensureCategoryDataComputed();
    return List.of(_orderedCategoryIds)..sort((a, b) {
      final nameA = _categories.getById(a)?.name ?? '';
      final nameB = _categories.getById(b)?.name ?? '';
      return nameA.toLowerCase().compareTo(nameB.toLowerCase());
    });
  }

  /// Location IDs sorted alphabetically by location name.
  List<String> get locationIdsSortedAlphabetically {
    _ensureLocationDataComputed();
    return List.of(_orderedLocationIds)..sort((a, b) {
      final nameA = _locations.getById(a)?.name ?? '';
      final nameB = _locations.getById(b)?.name ?? '';
      return nameA.toLowerCase().compareTo(nameB.toLowerCase());
    });
  }

  /// Category totals for this month, sorted by transaction count descending.
  List<CategoryTotal> get categoryTotalsThisMonthByFrequency {
    _ensureTotalsComputed();
    return List.of(_categoryTotalsThisMonth)..sort((a, b) => b.count.compareTo(a.count));
  }

  /// Category totals for this week, sorted by transaction count descending.
  List<CategoryTotal> get categoryTotalsThisWeekByFrequency {
    _ensureTotalsComputed();
    return List.of(_categoryTotalsThisWeek)..sort((a, b) => b.count.compareTo(a.count));
  }

  /// Location totals for this month, sorted by visit count descending.
  List<LocationTotal> get locationTotalsThisMonthByFrequency {
    _ensureTotalsComputed();
    return List.of(_locationTotalsThisMonth)..sort((a, b) => b.count.compareTo(a.count));
  }

  /// Location totals for this week, sorted by visit count descending.
  List<LocationTotal> get locationTotalsThisWeekByFrequency {
    _ensureTotalsComputed();
    return List.of(_locationTotalsThisWeek)..sort((a, b) => b.count.compareTo(a.count));
  }

  /// Category totals across all time, sorted by amount descending.
  List<CategoryTotal> get categoryTotalsAllTime {
    _ensureCategoryDataComputed();

    final totals = <CategoryTotal>[];
    for (final entry in _expensesByCategory.entries) {
      final categoryId = entry.key;
      final expenses = entry.value;
      final total = expenses.fold(0, (sum, e) => sum + (_convertToPrimary(e) ?? 0));

      totals.add(CategoryTotal(
        categoryId: categoryId,
        categoryName: _categories.getById(categoryId)?.name ??
            (categoryId.isEmpty ? 'Uncategorized' : 'Unknown'),
        totalMinor: total,
        count: expenses.length,
      ));
    }

    totals.sort((a, b) => b.totalMinor.compareTo(a.totalMinor));
    return totals;
  }

  /// Location totals for this week, sorted by amount descending.
  List<LocationTotal> get locationTotalsThisWeek {
    _ensureTotalsComputed();
    return List.unmodifiable(_locationTotalsThisWeek);
  }

  /// Location totals for this month, sorted by amount descending.
  List<LocationTotal> get locationTotalsThisMonth {
    _ensureTotalsComputed();
    return List.unmodifiable(_locationTotalsThisMonth);
  }

  /// Location totals across all time, sorted by amount descending.
  List<LocationTotal> get locationTotalsAllTime {
    _ensureLocationDataComputed();

    final totals = <LocationTotal>[];
    for (final entry in _expensesByLocation.entries) {
      final locationId = entry.key;
      final expenses = entry.value;
      final total = expenses.fold(0, (sum, e) => sum + (_convertToPrimary(e) ?? 0));

      totals.add(LocationTotal(
        locationId: locationId,
        locationName: _locations.getById(locationId)?.name ??
            (locationId.isEmpty ? 'No Location' : 'Unknown'),
        totalMinor: total,
        count: expenses.length,
      ));
    }

    totals.sort((a, b) => b.totalMinor.compareTo(a.totalMinor));
    return totals;
  }

  /// Category totals across all time, sorted by transaction count descending.
  List<CategoryTotal> get categoryTotalsAllTimeByFrequency {
    return categoryTotalsAllTime..sort((a, b) => b.count.compareTo(a.count));
  }

  /// Location totals across all time, sorted by visit count descending.
  List<LocationTotal> get locationTotalsAllTimeByFrequency {
    return locationTotalsAllTime..sort((a, b) => b.count.compareTo(a.count));
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Lazy Computation
  // ─────────────────────────────────────────────────────────────────────────
  // Private Helpers: Currency Conversion

  /// Convert expense amount to current primary currency.
  ///
  /// Uses stored primary currency conversion if the primary currency hasn't changed.
  /// Falls back to current rates if primary currency was changed.
  /// Returns null if conversion is not possible.
  int? _convertToPrimary(Expense expense) {
    final currentPrimary = _settings.primaryCurrency;

    // Best case: primary currency hasn't changed since expense creation
    if (expense.primaryCurrencyCode == currentPrimary &&
        expense.amountInPrimary != null) {
      return expense.amountInPrimary!;
    }

    // Optimization: expense is already in current primary currency
    if (expense.currencyCode == currentPrimary) {
      return expense.amountMinor;
    }

    // Fallback: primary changed or no conversion stored, use current rates
    final converted = _currencyService.convert(
      amountMinor: expense.amountMinor,
      from: expense.currencyCode,
      to: currentPrimary,
    );

    if (converted == null) {
      debugPrint(
        'ExpenseController: Failed to convert ${expense.currencyCode} to $currentPrimary',
      );
    }

    return converted;
  }

  // ─────────────────────────────────────────────────────────────────────────

  void _ensureTotalsComputed() {
    if (!_totalsNeedRecalc) return;
    _computeTotals();
    _totalsNeedRecalc = false;
  }

  void _ensureCategoryDataComputed() {
    if (!_categoryDataNeedRecalc) return;
    _computeCategoryData();
    _categoryDataNeedRecalc = false;
  }

  void _ensureLocationDataComputed() {
    if (!_locationDataNeedRecalc) return;
    _computeLocationData();
    _locationDataNeedRecalc = false;
  }

  /// Compute all totals in a single pass through the data.
  void _computeTotals() {
    final now = DateTime.now();
    final today = DateUtils.dateOnly(now);
    final sevenDaysAgo = today.subtract(const Duration(days: 6));
    final firstDayOfWeek = _settings.firstDayOfWeek;
    final daysFromWeekStart = (today.weekday - firstDayOfWeek + 7) % 7;
    final weekStart = today.subtract(Duration(days: daysFromWeekStart));
    final lastWeekStart = weekStart.subtract(const Duration(days: 7));
    final monthStart = DateTime(now.year, now.month);
    final lastMonthStart = DateTime(
      now.month == 1 ? now.year - 1 : now.year,
      now.month == 1 ? 12 : now.month - 1,
    );

    // Initialize accumulators
    int todayTotal = 0;
    int thisWeekTotal = 0;
    int lastWeekTotal = 0;
    int thisMonthTotal = 0;
    int lastMonthTotal = 0;
    int allTimeTotal = 0;

    // Initialize daily totals map for last 7 days
    final dailyTotals = <DateTime, int>{};
    final dailyCurrencyTotals = <DateTime, Map<String, int>>{};
    for (int i = 0; i < 7; i++) {
      dailyTotals[today.subtract(Duration(days: i))] = 0;
    }

    // Category totals for this month
    final categoryTotals = <String, int>{};
    final categoryCurrencyTotals = <String, Map<String, int>>{};
    final categoryCountsMonth = <String, int>{};

    // Category totals for last 7 days
    final categoryTotalsWeek = <String, int>{};
    final categoryTotalsWeekCurrency = <String, Map<String, int>>{};
    final categoryCountsWeek = <String, int>{};

    // Location totals for this month
    final locationTotals = <String, int>{};
    final locationCurrencyTotals = <String, Map<String, int>>{};
    final locationCountsMonth = <String, int>{};

    // Location totals for last 7 days
    final locationTotalsWeek = <String, int>{};
    final locationTotalsWeekCurrency = <String, Map<String, int>>{};
    final locationCountsWeek = <String, int>{};

    final daysThisMonth = <DateTime>{};
    final daysLastMonth = <DateTime>{};
    final monthsWithExpenses = <String>{};  // Track "YYYY-MM" format
    DateTime? firstExpense;

    // Single pass through all expenses
    for (final expense in _all) {
      final date = DateUtils.dateOnly(expense.date);
      final amount = _convertToPrimary(expense);
      if (amount == null) continue; // Skip unconverted expenses

      allTimeTotal += amount;

      // Track first expense
      if (firstExpense == null || date.isBefore(firstExpense)) {
        firstExpense = date;
      }

      // Track months with expenses
      monthsWithExpenses.add('${date.year}-${date.month}');

      // Today
      if (date == today) {
        todayTotal += amount;
      }

      // Rolling last 7 days: daily breakdown chart only
      if (!date.isBefore(sevenDaysAgo)) {
        if (dailyTotals.containsKey(date)) {
          dailyTotals[date] = dailyTotals[date]! + amount;

          // Track currency breakdown for daily totals
          dailyCurrencyTotals.putIfAbsent(date, () => {});
          dailyCurrencyTotals[date]!.update(
            expense.currencyCode,
            (v) => v + expense.amountMinor,
            ifAbsent: () => expense.amountMinor,
          );
        }
      }

      // This week (calendar): totals and category/location breakdowns
      if (!date.isBefore(weekStart)) {
        thisWeekTotal += amount;

        // Category breakdown for this week
        categoryTotalsWeek.update(
          expense.categoryId ?? '',
          (v) => v + amount,
          ifAbsent: () => amount,
        );

        categoryCountsWeek.update(expense.categoryId ?? '', (v) => v + 1, ifAbsent: () => 1);

        // Track currency breakdown for category week totals
        categoryTotalsWeekCurrency.putIfAbsent(expense.categoryId ?? '', () => {});
        categoryTotalsWeekCurrency[expense.categoryId ?? '']!.update(
          expense.currencyCode,
          (v) => v + expense.amountMinor,
          ifAbsent: () => expense.amountMinor,
        );

        // Location breakdown for this week
        locationTotalsWeek.update(
          expense.locationId ?? '',
          (v) => v + amount,
          ifAbsent: () => amount,
        );
        locationCountsWeek.update(expense.locationId ?? '', (v) => v + 1, ifAbsent: () => 1);

        // Track currency breakdown for location week totals
        locationTotalsWeekCurrency.putIfAbsent(expense.locationId ?? '', () => {});
        locationTotalsWeekCurrency[expense.locationId ?? '']!.update(
          expense.currencyCode,
          (v) => v + expense.amountMinor,
          ifAbsent: () => expense.amountMinor,
        );
      }

      // Last week (calendar, for comparison)
      if (!date.isBefore(lastWeekStart) && date.isBefore(weekStart)) {
        lastWeekTotal += amount;
      }

      // This month
      if (!date.isBefore(monthStart)) {
        thisMonthTotal += amount;
        daysThisMonth.add(date);

        // Category breakdown (use empty string for uncategorized)
        categoryTotals.update(
          expense.categoryId ?? '',
          (v) => v + amount,
          ifAbsent: () => amount,
        );

        categoryCountsMonth.update(expense.categoryId ?? '', (v) => v + 1, ifAbsent: () => 1);

        // Track currency breakdown for category month totals
        categoryCurrencyTotals.putIfAbsent(expense.categoryId ?? '', () => {});
        categoryCurrencyTotals[expense.categoryId ?? '']!.update(
          expense.currencyCode,
          (v) => v + expense.amountMinor,
          ifAbsent: () => expense.amountMinor,
        );

        // Location breakdown for this month
        locationTotals.update(
          expense.locationId ?? '',
          (v) => v + amount,
          ifAbsent: () => amount,
        );
        locationCountsMonth.update(expense.locationId ?? '', (v) => v + 1, ifAbsent: () => 1);

        // Track currency breakdown for location month totals
        locationCurrencyTotals.putIfAbsent(expense.locationId ?? '', () => {});
        locationCurrencyTotals[expense.locationId ?? '']!.update(
          expense.currencyCode,
          (v) => v + expense.amountMinor,
          ifAbsent: () => expense.amountMinor,
        );
      }

      // Last month
      if (!date.isBefore(lastMonthStart) && date.isBefore(monthStart)) {
        lastMonthTotal += amount;
        daysLastMonth.add(date);
      }
    }

    // Calculate daily average using calendar days since first expense
    final dayCount = firstExpense == null
        ? 1
        : today.difference(firstExpense).inDays + 1;
    final avgDaily = allTimeTotal ~/ dayCount;

    // Calculate weekly average using calendar weeks since first expense
    final weekCount = max(1, (dayCount + 6) ~/ 7);
    final avgWeekly = allTimeTotal ~/ weekCount;

    // Calculate daily average for this month
    final daysInThisMonth = daysThisMonth.isEmpty ? 1 : daysThisMonth.length;
    final thisMonthDaily = thisMonthTotal ~/ daysInThisMonth;

    // Calculate daily average for last month
    final daysInLastMonth = daysLastMonth.isEmpty ? 1 : daysLastMonth.length;
    final lastMonthDaily = lastMonthTotal ~/ daysInLastMonth;

    // Calculate monthly average
    final monthCount = monthsWithExpenses.isEmpty ? 1 : monthsWithExpenses.length;
    final avgMonthly = allTimeTotal ~/ monthCount;

    // Store computed values
    _totalToday = todayTotal;
    _totalThisWeek = thisWeekTotal;
    _totalThisMonth = thisMonthTotal;
    _totalAllTime = allTimeTotal;
    _totalLastWeek = lastWeekTotal;
    _totalLastMonth = lastMonthTotal;
    _dailyAverage = avgDaily;
    _weeklyAverage = avgWeekly;
    _thisMonthDailyAverage = thisMonthDaily;
    _lastMonthDailyAverage = lastMonthDaily;
    _monthlyAverage = avgMonthly;
    _firstExpenseDate = firstExpense;
    _dailyTotalsMinor = dailyTotals;
    _categoryTotalsMinor = categoryTotals;

    // Build sorted lists
    _last7DayTotals = dailyTotals.entries
        .map((e) {
          final breakdown = CurrencyBreakdownHelper.fromMap(
            dailyCurrencyTotals[e.key] ?? {},
          );
          return DailyTotal(
            date: e.key,
            totalMinor: e.value,
            currencyBreakdown: breakdown,
          );
        })
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    _categoryTotalsThisMonth = categoryTotals.entries
        .map((e) {
          final breakdown = CurrencyBreakdownHelper.fromMap(
            categoryCurrencyTotals[e.key] ?? {},
          );
          return CategoryTotal(
            categoryId: e.key,
            categoryName: _categories.getById(e.key)?.name ??
                (e.key.isEmpty ? 'Uncategorized' : 'Unknown'),
            totalMinor: e.value,
            count: categoryCountsMonth[e.key] ?? 0,
            currencyBreakdown: breakdown,
          );
        })
        .toList()
      ..sort((a, b) => b.totalMinor.compareTo(a.totalMinor));

    _categoryTotalsThisWeek = categoryTotalsWeek.entries
        .map((e) {
          final breakdown = CurrencyBreakdownHelper.fromMap(
            categoryTotalsWeekCurrency[e.key] ?? {},
          );
          return CategoryTotal(
            categoryId: e.key,
            categoryName: _categories.getById(e.key)?.name ??
                (e.key.isEmpty ? 'Uncategorized' : 'Unknown'),
            totalMinor: e.value,
            count: categoryCountsWeek[e.key] ?? 0,
            currencyBreakdown: breakdown,
          );
        })
        .toList()
      ..sort((a, b) => b.totalMinor.compareTo(a.totalMinor));

    _locationTotalsThisMonth = locationTotals.entries
        .map((e) {
          final breakdown = CurrencyBreakdownHelper.fromMap(
            locationCurrencyTotals[e.key] ?? {},
          );
          return LocationTotal(
            locationId: e.key,
            locationName: _locations.getById(e.key)?.name ??
                (e.key.isEmpty ? 'No Location' : 'Unknown'),
            totalMinor: e.value,
            count: locationCountsMonth[e.key] ?? 0,
            currencyBreakdown: breakdown,
          );
        })
        .toList()
      ..sort((a, b) => b.totalMinor.compareTo(a.totalMinor));

    _locationTotalsThisWeek = locationTotalsWeek.entries
        .map((e) {
          final breakdown = CurrencyBreakdownHelper.fromMap(
            locationTotalsWeekCurrency[e.key] ?? {},
          );
          return LocationTotal(
            locationId: e.key,
            locationName: _locations.getById(e.key)?.name ??
                (e.key.isEmpty ? 'No Location' : 'Unknown'),
            totalMinor: e.value,
            count: locationCountsWeek[e.key] ?? 0,
            currencyBreakdown: breakdown,
          );
        })
        .toList()
      ..sort((a, b) => b.totalMinor.compareTo(a.totalMinor));
  }

  /// Compute category grouping and ordering in a single pass.
  void _computeCategoryData() {
    // Group expenses by category and count in one pass
    final grouped = <String, List<Expense>>{};
    final counts = <String, int>{};

    for (final expense in _all) {
      // Use empty string for uncategorized expenses
      final categoryId = expense.categoryId ?? '';
      grouped.putIfAbsent(categoryId, () => []).add(expense);
      counts.update(categoryId, (v) => v + 1, ifAbsent: () => 1);
    }

    // Sort each category's expenses by date
    for (final list in grouped.values) {
      list.sort((a, b) => b.date.compareTo(a.date));
    }

    // Order categories by count (most used first)
    final orderedIds = counts.keys.toList()
      ..sort((a, b) => counts[b]!.compareTo(counts[a]!));

    // Store computed values
    _expensesByCategory = grouped;
    _orderedCategoryIds = orderedIds;
  }

  /// Compute location grouping and ordering in a single pass.
  void _computeLocationData() {
    // Group expenses by location and count in one pass
    final grouped = <String, List<Expense>>{};
    final counts = <String, int>{};

    for (final expense in _all) {
      // Use empty string for expenses without location
      final locationId = expense.locationId ?? '';
      grouped.putIfAbsent(locationId, () => []).add(expense);
      counts.update(locationId, (v) => v + 1, ifAbsent: () => 1);
    }

    // Sort each location's expenses by date
    for (final list in grouped.values) {
      list.sort((a, b) => b.date.compareTo(a.date));
    }

    // Order locations by count (most used first)
    final orderedIds = counts.keys.toList()
      ..sort((a, b) => counts[b]!.compareTo(counts[a]!));

    // Store computed values
    _expensesByLocation = grouped;
    _orderedLocationIds = orderedIds;
  }
}
