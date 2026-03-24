import '../models/expense_category.dart';

abstract class CategoryRepository {
  List<ExpenseCategory> getAll();
  ExpenseCategory? getById(String id);
  void save(ExpenseCategory category);
  void delete(String id);
  bool isEmpty();
}
