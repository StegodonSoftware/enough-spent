import 'expense_category.dart';

class DeleteResult {
  final ExpenseCategory? category;
  final bool wasDeleted;
  final bool wasDeactivated;

  DeleteResult._({
    this.category,
    this.wasDeleted = false,
    this.wasDeactivated = false,
  });

  factory DeleteResult.deleted(ExpenseCategory category) =>
      DeleteResult._(category: category, wasDeleted: true);

  factory DeleteResult.deactivated(ExpenseCategory category) =>
      DeleteResult._(category: category, wasDeactivated: true);

  factory DeleteResult.none() => DeleteResult._();
}
