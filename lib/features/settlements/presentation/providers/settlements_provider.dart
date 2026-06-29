import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_split/features/auth/presentation/providers/auth_provider.dart';
import 'package:easy_split/features/expenses/domain/services/debt_simplifier.dart';
import 'package:easy_split/features/expenses/presentation/providers/expenses_provider.dart';
import 'package:easy_split/features/groups/presentation/providers/groups_provider.dart';
import 'package:easy_split/features/settlements/data/repositories/settlements_repository_impl.dart';
import 'package:easy_split/features/settlements/domain/models/settlement.dart';
import 'package:easy_split/features/settlements/domain/repositories/settlements_repository.dart';

// ── Repository Provider ───────────────────────────────────────────

final settlementsRepositoryProvider = Provider<SettlementsRepository>((ref) {
  return SettlementsRepositoryImpl(api: ref.watch(apiServiceProvider));
});

// ── Group Settlements ─────────────────────────────────────────────

final groupSettlementsProvider =
    FutureProvider.family<List<Settlement>, String>((ref, groupId) async {
  return ref.read(settlementsRepositoryProvider).getGroupSettlements(groupId);
});

// ── Simplified Debts (Minimum Cash Flow Engine) ────────────────────

final simplifiedDebtsProvider =
    Provider.family<List<SimplifiedDebt>, String>((ref, groupId) {
  final group = ref.watch(groupDetailProvider(groupId)).valueOrNull;
  final expenses = ref.watch(groupExpensesProvider(groupId)).valueOrNull ?? [];
  final settlements = ref.watch(groupSettlementsProvider(groupId)).valueOrNull ?? [];

  if (group == null) return [];

  return DebtSimplifierService.calculate(
    members: group.members,
    expenses: expenses,
    settlements: settlements,
  );
});

// ── Settlements Notifier (My Settlements & Actions) ───────────────

class SettlementsNotifier extends AsyncNotifier<List<Settlement>> {
  @override
  Future<List<Settlement>> build() async {
    return ref.read(settlementsRepositoryProvider).getMySettlements();
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }

  Future<Settlement?> recordPayment({
    required String toUserId,
    String? groupId,
    required double amount,
    String paymentMethod = 'UPI',
    String? note,
  }) async {
    try {
      final settlement = await ref.read(settlementsRepositoryProvider).recordPayment(
            toUserId: toUserId,
            groupId: groupId,
            amount: amount,
            paymentMethod: paymentMethod,
            note: note,
          );
      ref.invalidateSelf();
      if (groupId != null && groupId.isNotEmpty) {
        ref.invalidate(groupDetailProvider(groupId));
        ref.invalidate(groupSettlementsProvider(groupId));
        ref.invalidate(groupsNotifierProvider);
      }
      return settlement;
    } catch (_) {
      return null;
    }
  }

  Future<bool> confirmPayment(String settlementId, {String? groupId}) async {
    try {
      await ref.read(settlementsRepositoryProvider).confirmPayment(settlementId);
      ref.invalidateSelf();
      if (groupId != null && groupId.isNotEmpty) {
        ref.invalidate(groupDetailProvider(groupId));
        ref.invalidate(groupSettlementsProvider(groupId));
        ref.invalidate(groupsNotifierProvider);
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> rejectPayment(String settlementId, {String? groupId}) async {
    try {
      await ref.read(settlementsRepositoryProvider).rejectPayment(settlementId);
      ref.invalidateSelf();
      if (groupId != null && groupId.isNotEmpty) {
        ref.invalidate(groupDetailProvider(groupId));
        ref.invalidate(groupSettlementsProvider(groupId));
        ref.invalidate(groupsNotifierProvider);
      }
      return true;
    } catch (_) {
      return false;
    }
  }
}

final settlementsNotifierProvider =
    AsyncNotifierProvider<SettlementsNotifier, List<Settlement>>(
        SettlementsNotifier.new);

// ── Dashboard Summary ─────────────────────────────────────────────

class DashboardSummary {
  final double totalOwed;    // you owe others
  final double totalOwedTo;  // others owe you
  final double netBalance;   // totalOwedTo - totalOwed

  const DashboardSummary({
    required this.totalOwed,
    required this.totalOwedTo,
  }) : netBalance = totalOwedTo - totalOwed;
}

final dashboardSummaryProvider = Provider<DashboardSummary>((ref) {
  final groups = ref.watch(groupsNotifierProvider).valueOrNull ?? [];
  double totalOwed = 0;
  double totalOwedTo = 0;

  for (final g in groups) {
    if (g.myBalance > 0) {
      totalOwedTo += g.myBalance;
    } else if (g.myBalance < 0) {
      totalOwed += g.myBalance.abs();
    }
  }

  return DashboardSummary(totalOwed: totalOwed, totalOwedTo: totalOwedTo);
});
