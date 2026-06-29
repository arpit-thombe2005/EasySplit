import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_split/features/auth/presentation/providers/auth_provider.dart';
import 'package:easy_split/features/groups/presentation/providers/groups_provider.dart';
import 'package:easy_split/features/settlements/data/repositories/settlements_repository_impl.dart';
import 'package:easy_split/features/settlements/domain/models/settlement.dart';
import 'package:easy_split/features/settlements/domain/repositories/settlements_repository.dart';
import 'package:easy_split/core/constants/app_constants.dart';
import 'package:easy_split/core/utils/debt_simplification.dart';

// ── Repository Provider ───────────────────────────────────────────

final settlementsRepositoryProvider = Provider<SettlementsRepository>((ref) {
  return SettlementsRepositoryImpl(api: ref.watch(apiServiceProvider));
});

// ── Simplified Debts ──────────────────────────────────────────────

final simplifiedDebtsProvider =
    FutureProvider.family<List<DebtTransaction>, String>((ref, groupId) async {
  return ref
      .read(settlementsRepositoryProvider)
      .getSimplifiedDebts(groupId);
});

// ── Settlements ───────────────────────────────────────────────────

class SettlementsNotifier extends AsyncNotifier<List<Settlement>> {
  @override
  Future<List<Settlement>> build() async {
    return ref.read(settlementsRepositoryProvider).getMySettlements();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(settlementsRepositoryProvider).getMySettlements(),
    );
  }

  Future<bool> markSettled(String settlementId) async {
    try {
      final updated =
          await ref.read(settlementsRepositoryProvider).markSettled(settlementId);
      final current = state.valueOrNull ?? [];
      state = AsyncData(
        current.map((s) => s.id == settlementId ? updated : s).toList(),
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<Settlement?> createSettlement({
    required String toUserId,
    required String groupId,
    required double amount,
  }) async {
    try {
      final settlement = await ref
          .read(settlementsRepositoryProvider)
          .createSettlement(toUserId: toUserId, groupId: groupId, amount: amount);
      final current = state.valueOrNull ?? [];
      state = AsyncData([settlement, ...current]);
      ref.invalidate(simplifiedDebtsProvider(groupId));
      return settlement;
    } catch (_) {
      return null;
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
  final settlements = ref.watch(settlementsNotifierProvider).valueOrNull ?? [];
  final pending = settlements.where((s) => s.status == SettlementStatus.pending);
  final currentUserId = ref.watch(currentUserProvider)?.id ?? '';

  double totalOwed = 0;
  double totalOwedTo = 0;

  for (final g in groups) {
    if (g.myBalance > 0) {
      totalOwedTo += g.myBalance;
    } else if (g.myBalance < 0) {
      totalOwed += g.myBalance.abs();
    }
  }

  for (final s in pending) {
    if (s.fromUser == currentUserId) {
      totalOwed += s.amount;
    } else if (s.toUser == currentUserId) {
      totalOwedTo += s.amount;
    }
  }

  return DashboardSummary(totalOwed: totalOwed, totalOwedTo: totalOwedTo);
});
