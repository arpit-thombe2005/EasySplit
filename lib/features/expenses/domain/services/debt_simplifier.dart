import 'dart:math';
import 'package:easy_split/features/expenses/domain/models/expense.dart';
import 'package:easy_split/features/groups/domain/models/group.dart';
import 'package:easy_split/features/settlements/domain/models/settlement.dart';

/// Service implementing the Minimum Cash Flow algorithm to minimize transactions.
class DebtSimplifierService {
  DebtSimplifierService._();

  /// Computes the minimal list of person-to-person transactions required to settle all debts in a group.
  static List<SimplifiedDebt> calculate({
    required List<GroupMember> members,
    required List<Expense> expenses,
    required List<Settlement> settlements,
  }) {
    final Map<String, String> userNameMap = {};
    final Map<String, double> netBalances = {};

    void registerUser(String? id, String? name) {
      if (id == null || id.isEmpty) return;
      netBalances.putIfAbsent(id, () => 0.0);
      if (name != null && name.isNotEmpty && name != 'Unknown' && name != 'Member') {
        userNameMap[id] = name;
      }
    }

    // 1. Register members
    for (final m in members) {
      registerUser(m.userId, m.user?.name);
    }

    // 2. Calculate expense contributions & shares
    for (final e in expenses) {
      final payerId = e.paidBy;
      registerUser(payerId, e.paidByUser?.name);
      netBalances[payerId] = (netBalances[payerId] ?? 0.0) + e.amount;

      for (final p in e.participants) {
        registerUser(p.userId, p.user?.name);
        netBalances[p.userId] = (netBalances[p.userId] ?? 0.0) - p.shareAmount;
      }
    }

    // 3. Adjust for COMPLETED settlements only (pending and rejected settlements do NOT alter net balances)
    for (final s in settlements) {
      registerUser(s.fromUser, s.fromUserName);
      registerUser(s.toUser, s.toUserName);
      if (s.status.toLowerCase() == 'completed') {
        netBalances[s.fromUser] = (netBalances[s.fromUser] ?? 0.0) + s.amount;
        netBalances[s.toUser] = (netBalances[s.toUser] ?? 0.0) - s.amount;
      }
    }

    // 4. Separate into creditors and debtors
    final List<_UserBalance> creditors = [];
    final List<_UserBalance> debtors = [];

    netBalances.forEach((userId, balance) {
      // Round to 2 decimal places to avoid floating point precision artifacts
      final rounded = double.parse(balance.toStringAsFixed(2));
      if (rounded > 0.01) {
        creditors.add(_UserBalance(userId, rounded));
      } else if (rounded < -0.01) {
        debtors.add(_UserBalance(userId, rounded.abs()));
      }
    });

    // Sort descending by magnitude
    creditors.sort((a, b) => b.amount.compareTo(a.amount));
    debtors.sort((a, b) => b.amount.compareTo(a.amount));

    final List<SimplifiedDebt> result = [];
    int i = 0; // index for creditors
    int j = 0; // index for debtors

    // 5. Greedy Minimum Cash Flow algorithm execution
    while (i < creditors.length && j < debtors.length) {
      final creditor = creditors[i];
      final debtor = debtors[j];

      final settledAmount = min(creditor.amount, debtor.amount);
      final roundedSettled = double.parse(settledAmount.toStringAsFixed(2));

      if (roundedSettled > 0.01) {
        result.add(SimplifiedDebt(
          fromUserId: debtor.userId,
          fromUserName: userNameMap[debtor.userId] ?? 'Member',
          toUserId: creditor.userId,
          toUserName: userNameMap[creditor.userId] ?? 'Member',
          amount: roundedSettled,
        ));
      }

      creditor.amount -= settledAmount;
      debtor.amount -= settledAmount;

      if (creditor.amount <= 0.01) i++;
      if (debtor.amount <= 0.01) j++;
    }

    return result;
  }
}

class _UserBalance {
  final String userId;
  double amount;
  _UserBalance(this.userId, this.amount);
}
