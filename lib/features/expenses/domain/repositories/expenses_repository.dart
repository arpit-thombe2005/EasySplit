import 'package:easy_split/features/expenses/domain/models/expense.dart';

/// Abstract repository interface for expense operations.
abstract class ExpensesRepository {
  /// Fetch all expenses for a group (paginated).
  Future<List<Expense>> getGroupExpenses({
    required String groupId,
    int page = 1,
    int limit = 20,
  });

  /// Fetch a single expense by ID.
  Future<Expense> getExpense(String expenseId);

  /// Create a new expense.
  Future<Expense> createExpense(ExpenseInput input);

  /// Update an existing expense.
  Future<Expense> updateExpense({
    required String expenseId,
    required ExpenseInput input,
  });

  /// Delete an expense.
  Future<void> deleteExpense(String expenseId);

  /// Fetch all expenses involving the current user (across all groups).
  Future<List<Expense>> getMyExpenses({int page = 1, int limit = 20});
}
