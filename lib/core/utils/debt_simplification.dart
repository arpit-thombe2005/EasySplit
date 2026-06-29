import 'dart:math';
import 'package:easy_split/core/constants/app_constants.dart';

/// Debt Simplification Algorithm
///
/// Minimizes the number of transactions required to settle all balances
/// in a group using a greedy min-cash-flow approach.
///
/// Time Complexity: O(n²) where n = number of people
/// Space Complexity: O(n)
class DebtSimplificationService {
  DebtSimplificationService._();

  /// Simplifies a list of raw debts into the minimum number of transactions.
  ///
  /// [rawTransactions] is a list of (from, to, amount) records.
  /// Returns a simplified list of [DebtTransaction]s.
  static List<DebtTransaction> simplify(List<DebtTransaction> rawTransactions) {
    if (rawTransactions.isEmpty) return [];

    // Aggregate net balance per person
    final Map<String, double> netBalance = {};
    for (final tx in rawTransactions) {
      netBalance[tx.fromUserId] = (netBalance[tx.fromUserId] ?? 0) - tx.amount;
      netBalance[tx.toUserId] = (netBalance[tx.toUserId] ?? 0) + tx.amount;
    }

    // Separate creditors (+) and debtors (-)
    final creditors = <_BalanceEntry>[];
    final debtors = <_BalanceEntry>[];

    for (final entry in netBalance.entries) {
      if (entry.value > 0.001) {
        creditors.add(_BalanceEntry(entry.key, entry.value));
      } else if (entry.value < -0.001) {
        debtors.add(_BalanceEntry(entry.key, -entry.value));
      }
    }

    // Sort for deterministic output
    creditors.sort((a, b) => b.amount.compareTo(a.amount));
    debtors.sort((a, b) => b.amount.compareTo(a.amount));

    final result = <DebtTransaction>[];
    int ci = 0, di = 0;

    while (ci < creditors.length && di < debtors.length) {
      final credit = creditors[ci];
      final debt = debtors[di];

      final transferAmount = min(credit.amount, debt.amount);
      result.add(DebtTransaction(
        fromUserId: debt.userId,
        toUserId: credit.userId,
        amount: double.parse(transferAmount.toStringAsFixed(2)),
        fromUserName: debt.userId,
        toUserName: credit.userId,
      ));

      credit.amount -= transferAmount;
      debt.amount -= transferAmount;

      if (credit.amount < 0.001) ci++;
      if (debt.amount < 0.001) di++;
    }

    return result;
  }

  /// Calculate group balances from expenses and settlements.
  ///
  /// Returns a map of userId → net balance amount.
  /// Positive = owed money. Negative = owes money.
  static Map<String, double> calculateGroupBalances({
    required List<ExpenseDebtRecord> expenses,
    required List<SettledRecord> settlements,
  }) {
    final Map<String, double> balances = {};

    // Add expense shares (debts from expense participants to payer)
    for (final expense in expenses) {
      // Payer is owed money
      balances[expense.paidBy] =
          (balances[expense.paidBy] ?? 0) + expense.totalAmount;

      // Each participant owes their share
      for (final share in expense.shares) {
        balances[share.userId] =
            (balances[share.userId] ?? 0) - share.shareAmount;
      }
    }

    // Apply settlements (reduce debts)
    for (final settlement in settlements) {
      if (settlement.status == SettlementStatus.completed) {
        balances[settlement.fromUser] =
            (balances[settlement.fromUser] ?? 0) + settlement.amount;
        balances[settlement.toUser] =
            (balances[settlement.toUser] ?? 0) - settlement.amount;
      }
    }

    return balances;
  }
}

class _BalanceEntry {
  final String userId;
  double amount;
  _BalanceEntry(this.userId, this.amount);
}

/// Represents a single debt transaction (who owes whom how much)
class DebtTransaction {
  final String fromUserId;
  final String toUserId;
  final double amount;
  final String fromUserName;
  final String toUserName;

  const DebtTransaction({
    required this.fromUserId,
    required this.toUserId,
    required this.amount,
    required this.fromUserName,
    required this.toUserName,
  });
}

/// Input record: an expense with all participant shares
class ExpenseDebtRecord {
  final String paidBy;
  final double totalAmount;
  final List<ParticipantShare> shares;

  const ExpenseDebtRecord({
    required this.paidBy,
    required this.totalAmount,
    required this.shares,
  });
}

/// A single participant's share in an expense
class ParticipantShare {
  final String userId;
  final double shareAmount;

  const ParticipantShare({required this.userId, required this.shareAmount});
}

/// A completed or pending settlement record
class SettledRecord {
  final String fromUser;
  final String toUser;
  final double amount;
  final SettlementStatus status;

  const SettledRecord({
    required this.fromUser,
    required this.toUser,
    required this.amount,
    required this.status,
  });
}
