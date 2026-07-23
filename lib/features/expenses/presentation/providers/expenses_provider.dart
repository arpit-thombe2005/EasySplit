import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_split/core/constants/app_constants.dart';
import 'package:easy_split/features/auth/presentation/providers/auth_provider.dart';
import 'package:easy_split/features/expenses/data/repositories/expenses_repository_impl.dart';
import 'package:easy_split/features/expenses/domain/models/expense.dart';
import 'package:easy_split/features/expenses/domain/repositories/expenses_repository.dart';
import 'package:easy_split/features/expenses/domain/services/split_calculator.dart';

// ── Repository Provider ───────────────────────────────────────────

final expensesRepositoryProvider = Provider<ExpensesRepository>((ref) {
  return ExpensesRepositoryImpl(api: ref.watch(apiServiceProvider));
});

// ── Group Expenses ────────────────────────────────────────────────

final groupExpensesProvider =
    FutureProvider.family<List<Expense>, String>((ref, groupId) async {
  return ref
      .read(expensesRepositoryProvider)
      .getGroupExpenses(groupId: groupId);
});

final userExpensesProvider = FutureProvider<List<Expense>>((ref) async {
  return ref.read(expensesRepositoryProvider).getMyExpenses();
});

// ── Add Expense Form ──────────────────────────────────────────────

class AddExpenseState {
  final bool isLoading;
  final String? error;
  final String category;
  final SplitType splitType;
  final Map<String, double> exactAmounts;
  final Map<String, double> percentages;
  final Map<String, int> shares;

  const AddExpenseState({
    this.isLoading = false,
    this.error,
    this.category = 'Other',
    this.splitType = SplitType.equal,
    this.exactAmounts = const {},
    this.percentages = const {},
    this.shares = const {},
  });

  AddExpenseState copyWith({
    bool? isLoading,
    String? error,
    bool clearError = false,
    String? category,
    SplitType? splitType,
    Map<String, double>? exactAmounts,
    Map<String, double>? percentages,
    Map<String, int>? shares,
  }) =>
      AddExpenseState(
        isLoading: isLoading ?? this.isLoading,
        error: clearError ? null : (error ?? this.error),
        category: category ?? this.category,
        splitType: splitType ?? this.splitType,
        exactAmounts: exactAmounts ?? this.exactAmounts,
        percentages: percentages ?? this.percentages,
        shares: shares ?? this.shares,
      );
}

class AddExpenseNotifier extends Notifier<AddExpenseState> {
  @override
  AddExpenseState build() => const AddExpenseState();

  void setCategory(String category) =>
      state = state.copyWith(category: category);

  void setSplitType(SplitType type) =>
      state = state.copyWith(splitType: type);

  void setExactAmount(String userId, double amount) => state = state.copyWith(
        exactAmounts: {...state.exactAmounts, userId: amount},
      );

  void setPercentage(String userId, double pct) => state = state.copyWith(
        percentages: {...state.percentages, userId: pct},
      );

  void setShares(String userId, int count) => state = state.copyWith(
        shares: {...state.shares, userId: count},
      );

  Future<Expense?> submitExpense({
    required String groupId,
    required String paidBy,
    required String title,
    required double amount,
    required List<String> participantIds,
    DateTime? expenseDate,
    String? notes,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      // Compute split
      final participants = SplitCalculatorService.compute(
        totalAmount: amount,
        userIds: participantIds,
        splitType: state.splitType,
        exactAmounts: state.exactAmounts,
        percentages: state.percentages,
        shares: state.shares,
      );

      final input = ExpenseInput(
        groupId: groupId,
        paidBy: paidBy,
        title: title,
        amount: amount,
        category: state.category,
        notes: notes,
        splitType: state.splitType,
        participants: participants,
        expenseDate: expenseDate,
      );

      final expense =
          await ref.read(expensesRepositoryProvider).createExpense(input);

      // Invalidate group expenses cache
      ref.invalidate(groupExpensesProvider(groupId));
      ref.invalidate(userExpensesProvider);

      state = const AddExpenseState();
      return expense;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
      return null;
    }
  }

  Future<Expense?> updateExpense({
    required String expenseId,
    required String groupId,
    required String paidBy,
    required String title,
    required double amount,
    required List<String> participantIds,
    DateTime? expenseDate,
    String? notes,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final participants = SplitCalculatorService.compute(
        totalAmount: amount,
        userIds: participantIds,
        splitType: state.splitType,
        exactAmounts: state.exactAmounts,
        percentages: state.percentages,
        shares: state.shares,
      );

      final input = ExpenseInput(
        groupId: groupId,
        paidBy: paidBy,
        title: title,
        amount: amount,
        category: state.category,
        notes: notes,
        splitType: state.splitType,
        participants: participants,
        expenseDate: expenseDate,
      );

      final expense = await ref.read(expensesRepositoryProvider).updateExpense(
            expenseId: expenseId,
            input: input,
          );

      ref.invalidate(groupExpensesProvider(groupId));
      ref.invalidate(userExpensesProvider);

      state = const AddExpenseState();
      return expense;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
      return null;
    }
  }

  Future<bool> deleteExpense(String expenseId, String groupId) async {
    try {
      await ref.read(expensesRepositoryProvider).deleteExpense(expenseId);
      ref.invalidate(groupExpensesProvider(groupId));
      ref.invalidate(userExpensesProvider);
      return true;
    } catch (e) {
      return false;
    }
  }

  void reset() => state = const AddExpenseState();
}

final addExpenseNotifierProvider =
    NotifierProvider<AddExpenseNotifier, AddExpenseState>(
        AddExpenseNotifier.new);
