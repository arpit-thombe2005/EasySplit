import 'package:easy_split/core/services/api_service.dart';
import 'package:easy_split/features/expenses/domain/models/expense.dart';
import 'package:easy_split/features/expenses/domain/repositories/expenses_repository.dart';

/// Concrete implementation of [ExpensesRepository].
class ExpensesRepositoryImpl implements ExpensesRepository {
  final ApiService _api;

  ExpensesRepositoryImpl({required ApiService api}) : _api = api;

  @override
  Future<List<Expense>> getGroupExpenses({
    required String groupId,
    int page = 1,
    int limit = 20,
  }) async {
    final data = await _api.get(
      '/groups/$groupId/expenses',
      queryParameters: {'page': page, 'limit': limit},
    );
    final list = data['expenses'] as List<dynamic>;
    return list.map((e) => Expense.fromJson(e as Map<String, dynamic>)).toList();
  }

  @override
  Future<Expense> getExpense(String expenseId) async {
    final data = await _api.get('/expenses/$expenseId');
    return Expense.fromJson(data['expense'] as Map<String, dynamic>);
  }

  @override
  Future<Expense> createExpense(ExpenseInput input) async {
    final payload = {
      'group_id': input.groupId,
      'paid_by': input.paidBy,
      'title': input.title,
      'amount': input.amount,
      'category': input.category,
      if (input.notes != null) 'notes': input.notes,
      'split_type': input.splitType.name,
      'expense_date': (input.expenseDate ?? DateTime.now()).toIso8601String(),
      'participants': input.participants.map((p) => {
        'user_id': p.userId,
        'share_amount': p.shareAmount,
        'percentage': p.percentage,
        'shares': p.shares,
      }).toList(),
    };

    final responseData = await _api.post('/expenses', data: payload);
    return Expense.fromJson(responseData['expense'] as Map<String, dynamic>);
  }

  @override
  Future<Expense> updateExpense({
    required String expenseId,
    required ExpenseInput input,
  }) async {
    final data = await _api.put('/expenses/$expenseId', data: {
      'title': input.title,
      'amount': input.amount,
      'category': input.category,
      if (input.notes != null) 'notes': input.notes,
      'split_type': input.splitType.name,
      'expense_date': (input.expenseDate ?? DateTime.now()).toIso8601String(),
      'participants': input.participants.map((p) => {
        'user_id': p.userId,
        'share_amount': p.shareAmount,
        'percentage': p.percentage,
        'shares': p.shares,
      }).toList(),
    });
    return Expense.fromJson(data['expense'] as Map<String, dynamic>);
  }

  @override
  Future<void> deleteExpense(String expenseId) async {
    await _api.delete('/expenses/$expenseId');
  }

  @override
  Future<List<Expense>> getMyExpenses({int page = 1, int limit = 20}) async {
    final data = await _api.get(
      '/expenses/me',
      queryParameters: {'page': page, 'limit': limit},
    );
    final list = data['expenses'] as List<dynamic>;
    return list.map((e) => Expense.fromJson(e as Map<String, dynamic>)).toList();
  }
}
