import '../models/expense.dart';

abstract class ExpenseRepository {
  List<Expense> getAll();
  List<Expense> allSortedByDateDesc();
  Expense? getById(String id);

  /// Creates or updates an expense by ID
  void save(Expense expense);

  void delete(String id);

  /// Deletes all expenses. Use with caution.
  void deleteAll();

  bool isCategoryUsed(String categoryId);

  int countByCategory(String categoryId);

  bool isLocationUsed(String locationId);

  int countByLocation(String locationId);

  /// Returns a map of locationId -> usage count for all locations
  Map<String, int> getLocationUsageCounts();

  /// Clears locationId from all expenses that reference this location.
  /// Returns the list of expense IDs that were updated.
  List<String> clearLocationFromExpenses(String locationId);

  /// Updates locationId on all expenses from oldLocationId to newLocationId.
  /// Used for merging locations. Returns the list of expense IDs that were updated.
  List<String> updateLocationOnExpenses(String oldLocationId, String newLocationId);

  /// Restores locationId on the specified expenses.
  /// Used for undo operations.
  void restoreLocationOnExpenses(List<String> expenseIds, String locationId);

  /// Updates multiple expenses in batch.
  /// Used for bulk operations like currency conversion.
  void saveBatch(List<Expense> expenses);
}
